const MAX_BYTES = 5 * 1024 * 1024;
const TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);
const ID = '[A-Za-z0-9_-]{1,128}';
const uploadRoute = new RegExp(`^/reports/(${ID})/photo$`);
const imageRoute = new RegExp(`^/reports/(${ID})/photo/([a-f0-9]{64})\\.(jpg|jpeg|png|webp)$`);

class RequestError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
function requireCondition(condition, status, message) {
  if (!condition) throw new RequestError(status, message);
}
const json = (data, status = 200) => new Response(JSON.stringify(data), {
  status, headers: {'Content-Type': 'application/json', 'Cache-Control': 'no-store'},
});
async function digest(algorithm, value) {
  const result = await crypto.subtle.digest(algorithm, typeof value === 'string' ? new TextEncoder().encode(value) : value);
  return [...new Uint8Array(result)].map(byte => byte.toString(16).padStart(2, '0')).join('');
}
export async function signCloudinary(parameters, secret) {
  const ordered = Object.keys(parameters).sort().map(key => `${key}=${parameters[key]}`).join('&');
  return digest('SHA-1', ordered + secret);
}
function imageMatches(bytes, type) {
  if (type === 'image/jpeg') return bytes.length >= 3 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
  if (type === 'image/png') return bytes.length >= 8 && [137,80,78,71,13,10,26,10].every((byte, index) => bytes[index] === byte);
  return bytes.length >= 12 && new TextDecoder().decode(bytes.slice(0,4)) === 'RIFF' && new TextDecoder().decode(bytes.slice(8,12)) === 'WEBP';
}
async function boundedBody(request) {
  const announced = request.headers.get('Content-Length');
  requireCondition(!announced || Number(announced) <= MAX_BYTES, 413, 'Choose a photo smaller than 5 MB.');
  requireCondition(request.body, 400, 'Photo is empty.');
  const reader = request.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      size += value.length;
      if (size > MAX_BYTES) { await reader.cancel(); throw new RequestError(413, 'Choose a photo smaller than 5 MB.'); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  requireCondition(size > 0, 400, 'Photo is empty.');
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return bytes;
}

/** Private image proxy. Firebase verifies tokens; Firestore enforces report
 * access; Cloudinary credentials and signed download links never reach clients. */
export function createPhotoWorker({fetcher = fetch, now = () => Date.now()} = {}) {
  async function upstream(url, options = {}) {
    try { return await fetcher(url, {...options, signal: AbortSignal.timeout(15000)}); }
    catch { throw new RequestError(503, 'Photo service unavailable. Please retry.'); }
  }
  async function actor(token, env) {
    const response = await upstream(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(env.FIREBASE_API_KEY)}`, {
      method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({idToken: token}),
    });
    requireCondition(response.ok, response.status >= 500 ? 503 : 401, 'Sign in again to access photos.');
    const profile = (await response.json()).users?.[0];
    let claims;
    try { claims = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))); }
    catch { throw new RequestError(401, 'Invalid sign-in token.'); }
    requireCondition(profile?.localId && claims.sub === profile.localId &&
      claims.aud === env.FIREBASE_PROJECT_ID && claims.iss === `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}` &&
      claims.exp * 1000 > now(), 401, 'Invalid or expired sign-in token.');
    return {uid: profile.localId, clo: claims.role === 'clo', demo: claims.isDemo === true};
  }
  async function readReport(id, token, env) {
    const response = await upstream(`https://firestore.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/databases/(default)/documents/conflictReports/${id}`, {
      headers: {Authorization: `Bearer ${token}`},
    });
    if (response.status === 404) return null;
    requireCondition(response.ok, response.status === 403 ? 403 : 503, 'Report photo access denied or unavailable.');
    const {fields} = await response.json();
    return {owner: fields?.reporterId?.stringValue, demo: fields?.isDemo?.booleanValue === true,
      photoUrl: fields?.photoUrl?.stringValue};
  }
  async function handle(request, env) {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/health') return json({service: 'wildora-conflict-photos'});
    requireCondition(url.protocol === 'https:' || url.hostname === 'localhost' || url.hostname === '127.0.0.1', 400, 'HTTPS required.');
    const match = request.method === 'POST' ? uploadRoute.exec(url.pathname) : request.method === 'GET' ? imageRoute.exec(url.pathname) : null;
    requireCondition(match && !url.search, 404, 'Photo endpoint not found.');
    for (const name of ['FIREBASE_API_KEY','FIREBASE_PROJECT_ID','CLOUDINARY_CLOUD_NAME','CLOUDINARY_API_KEY','CLOUDINARY_API_SECRET']) {
      requireCondition(env[name], 503, 'Photo service configuration is incomplete.');
    }
    const authorization = request.headers.get('Authorization') || '';
    requireCondition(/^Bearer [A-Za-z0-9._-]{20,8192}$/.test(authorization), 401, 'Sign in to access photos.');
    const token = authorization.slice(7);
    const user = await actor(token, env);
    const id = match[1];
    const report = await readReport(id, token, env);
    const timestamp = Math.floor(now()/1000);
    if (request.method === 'GET') {
      requireCondition(report, 404, 'Report not found.');
      requireCondition(report.owner === user.uid || (user.clo && (!user.demo || report.demo)), 403, 'Only the reporter or an authorized CLO can view this photo.');
      requireCondition(report.photoUrl === url.href && report.owner, 404, 'Report photo not found.');
      const parameters = {public_id: `wildora/${report.owner}/${id}/${match[2]}`, format: match[3], type: 'authenticated',
        attachment: 'false', timestamp, expires_at: timestamp + 60};
      const query = new URLSearchParams({...parameters, api_key: env.CLOUDINARY_API_KEY,
        signature: await signCloudinary(parameters, env.CLOUDINARY_API_SECRET)});
      const image = await upstream(`https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD_NAME}/image/download?${query}`);
      requireCondition(image.ok && TYPES.has(image.headers.get('Content-Type')?.split(';')[0]), 502, 'Photo unavailable. Please retry later.');
      return new Response(image.body, {headers: {'Content-Type': image.headers.get('Content-Type'),
        'Cache-Control': 'private, no-store', 'Vary': 'Authorization', 'X-Content-Type-Options': 'nosniff'}});
    }
    requireCondition(!report || report.owner === user.uid, 403, 'Only the reporter can attach this photo.');
    requireCondition(env.UPLOAD_LIMITER && (await env.UPLOAD_LIMITER.limit({key: user.uid})).success, 429, 'Too many photo uploads. Please try again later.');
    const type = request.headers.get('Content-Type')?.split(';')[0];
    requireCondition(TYPES.has(type), 415, 'Choose a JPEG, PNG or WebP photo.');
    const bytes = await boundedBody(request);
    requireCondition(imageMatches(bytes, type), 415, 'The photo format does not match its content.');
    if (report?.photoUrl) {
      requireCondition(report.photoUrl.startsWith(`${url.origin}/reports/${id}/photo/`), 409, 'This report already has a photo from another provider.');
      return json({photoUrl: report.photoUrl, reporterId: user.uid});
    }
    const hash = await digest('SHA-256', bytes);
    const publicId = `wildora/${user.uid}/${id}/${hash}`;
    const parameters = {public_id: publicId, type: 'authenticated', overwrite: 'false', timestamp};
    const form = new FormData();
    for (const [name, value] of Object.entries(parameters)) form.set(name, String(value));
    form.set('api_key', env.CLOUDINARY_API_KEY);
    form.set('signature', await signCloudinary(parameters, env.CLOUDINARY_API_SECRET));
    form.set('file', new Blob([bytes], {type}), 'incident-photo');
    const uploaded = await upstream(`https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD_NAME}/image/upload`, {method: 'POST', body: form});
    requireCondition(uploaded.ok, 502, 'Photo upload failed. The report remains saved on your device.');
    const asset = await uploaded.json();
    requireCondition(asset.public_id === publicId && asset.type === 'authenticated' && /^(jpg|jpeg|png|webp)$/.test(asset.format), 502, 'Photo upload acknowledgement is invalid.');
    return json({photoUrl: `${url.origin}/reports/${id}/photo/${hash}.${asset.format}`, reporterId: user.uid});
  }
  return {
    async fetch(request, env) {
      const origin = request.headers.get('Origin');
      const allowed = new Set((env.ALLOWED_ORIGINS || '').split(',').map(value => value.trim()).filter(Boolean));
      if (origin && !allowed.has(origin)) return json({error: 'Origin is not allowed.'}, 403);
      let response;
      if (request.method === 'OPTIONS') response = new Response(null, {status: 204});
      else {
        try { response = await handle(request, env); }
        catch (error) { response = json({error: error instanceof RequestError ? error.message : 'Photo service unavailable.'}, error instanceof RequestError ? error.status : 503); }
      }
      const headers = new Headers(response.headers);
      headers.set('X-Content-Type-Options', 'nosniff');
      if (origin) {
        headers.set('Access-Control-Allow-Origin', origin);
        headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        headers.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
        headers.append('Vary', 'Origin');
      }
      return new Response(response.body, {status: response.status, headers});
    },
  };
}
export default createPhotoWorker();
