import test from 'node:test';
import assert from 'node:assert/strict';
import {createPhotoWorker, signCloudinary} from '../src/worker.mjs';

const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGOYOWPmfwAGvwMZ9gcQLgAAAABJRU5ErkJggg==', 'base64');
const time = 1791890000000;
const environment = {FIREBASE_PROJECT_ID: 'project-test', FIREBASE_API_KEY: 'public-firebase-key', CLOUDINARY_CLOUD_NAME: 'cloud-test',
  CLOUDINARY_API_KEY: 'cloud-key', CLOUDINARY_API_SECRET: 'server-secret', ALLOWED_ORIGINS: 'https://app.example',
  UPLOAD_LIMITER: {limit: async () => ({success: true})}};
function token(uid = 'owner', extra = {}) {
  return 'header.' + Buffer.from(JSON.stringify({sub: uid, aud: 'project-test', iss: 'https://securetoken.google.com/project-test',
    exp: time/1000 + 300, ...extra})).toString('base64url') + '.signature';
}
function setup({report = null, uid = 'owner', extra = {}, uploadFails = false, downloadFails = false, authFails = false} = {}) {
  const calls = [];
  const worker = createPhotoWorker({now: () => time, fetcher: async (address, options) => {
    calls.push({address, options});
    if (address.includes('accounts:lookup')) return authFails ? new Response('{}', {status: 400}) : Response.json({users: [{localId: uid}]});
    if (address.includes('firestore.googleapis.com')) return report ? Response.json({fields: {
      reporterId: {stringValue: report.owner || 'owner'}, isDemo: {booleanValue: report.demo || false}, photoUrl: {stringValue: report.photoUrl || ''},
    }}) : new Response('{}', {status: 404});
    if (address.endsWith('/image/upload')) return uploadFails ? new Response('{}', {status: 502}) : Response.json({
      public_id: options.body.get('public_id'), type: 'authenticated', format: 'png',
    });
    if (address.includes('/image/download?')) return downloadFails ? new Response('{}', {status: 404}) : new Response(png, {headers: {'Content-Type': 'image/png'}});
    throw Error('Unexpected upstream call');
  }});
  const authorization = `Bearer ${token(uid, extra)}`;
  return {calls, worker, authorization,
    upload: (options = {}) => worker.fetch(new Request('https://photos.example/reports/report-1/photo', {
      method: 'POST', headers: {Authorization: authorization, 'Content-Type': 'image/png', ...options.headers}, body: options.body ?? png,
    }), {...environment, ...options.env}),
    download: url => worker.fetch(new Request(url, {headers: {Authorization: authorization}}), environment)};
}
const hash = 'a'.repeat(64);
const photoUrl = `https://photos.example/reports/report-1/photo/${hash}.png`;

test('signed upload is authenticated, private and content-addressed on retry', async () => {
  const app = setup();
  const first = await app.upload();
  assert.equal(first.status, 200);
  const data = await first.json();
  assert.match(data.photoUrl, /^https:\/\/photos.example\/reports\/report-1\/photo\/[a-f0-9]{64}\.png$/);
  assert.equal(data.reporterId, 'owner');
  assert.equal((await (await app.upload()).json()).photoUrl, data.photoUrl);
  const calls = app.calls.filter(call => call.address.endsWith('/image/upload'));
  assert.equal(calls[0].options.body.get('type'), 'authenticated');
  assert.equal(calls[0].options.body.get('overwrite'), 'false');
  assert.equal(calls[0].options.body.get('public_id'), calls[1].options.body.get('public_id'));
  assert.equal(JSON.stringify(data).includes('server-secret'), false);
  assert.equal(JSON.stringify(data).includes('signature'), false);
});
test('missing authorization is denied before any upstream call', async () => {
  const app = setup();
  const response = await app.worker.fetch(new Request('https://photos.example/reports/report-1/photo', {method: 'POST', body: png}), environment);
  assert.equal(response.status, 401); assert.equal(app.calls.length, 0);
});
test('invalid Firebase token cannot upload', async () => {
  const app = setup({authFails: true}); assert.equal((await app.upload()).status, 401);
  assert.equal(app.calls.length, 1);
});
test('expired token is rejected even if lookup returns an account', async () => {
  const app = setup({extra: {exp: time/1000 - 1}}); assert.equal((await app.upload()).status, 401);
});
test('token from another project is rejected', async () => {
  const app = setup({extra: {aud: 'another-project'}}); assert.equal((await app.upload()).status, 401);
});
test('only the reporter can attach an existing report photo', async () => {
  const app = setup({uid: 'other', report: {owner: 'owner'}});
  assert.equal((await app.upload()).status, 403);
  assert.equal(app.calls.filter(call => call.address.includes('cloudinary')).length, 0);
});
test('upload-rate exhaustion prevents photo storage', async () => {
  const app = setup();
  assert.equal((await app.upload({env: {UPLOAD_LIMITER: {limit: async () => ({success: false})}}})).status, 429);
});
test('empty image is rejected', async () => {
  const app = setup(); assert.equal((await app.upload({body: new Uint8Array()})).status, 400);
});
test('oversized image is rejected using content length', async () => {
  const app = setup(); assert.equal((await app.upload({headers: {'Content-Length': String(5*1024*1024+1)}})).status, 413);
});
test('oversized unannounced body is bounded during streaming', async () => {
  const app = setup(); assert.equal((await app.upload({body: new Uint8Array(5*1024*1024+1)})).status, 413);
});
test('unsupported type and mismatched bytes are rejected', async () => {
  assert.equal((await setup().upload({headers: {'Content-Type': 'image/svg+xml'}})).status, 415);
  assert.equal((await setup().upload({body: new Uint8Array([1,2,3])})).status, 415);
});
test('cloud upload failure does not acknowledge a photo', async () => {
  const app = setup({uploadFails: true}); const response = await app.upload();
  assert.equal(response.status, 502); assert.equal((await response.json()).photoUrl, undefined);
});
test('a previously recorded photo is reused without another cloud upload', async () => {
  const app = setup({report: {photoUrl}});
  assert.equal((await (await app.upload()).json()).photoUrl, photoUrl);
  assert.equal(app.calls.filter(call => call.address.includes('cloudinary')).length, 0);
});
test('owner download returns image bytes, without exposing signed cloud URL', async () => {
  const app = setup({report: {photoUrl}}); const response = await app.download(photoUrl);
  assert.equal(response.status, 200); assert.equal(response.headers.get('Cache-Control'), 'private, no-store');
  assert.deepEqual(Buffer.from(await response.arrayBuffer()), png);
  assert.equal(response.headers.get('Location'), null);
});
test('an unrelated signed-in member cannot view a demo photo', async () => {
  const app = setup({uid: 'other', report: {demo: true, photoUrl}});
  assert.equal((await app.download(photoUrl)).status, 403);
});
test('real CLO can view a report photo', async () => {
  const app = setup({uid: 'clo', extra: {role: 'clo'}, report: {photoUrl}});
  assert.equal((await app.download(photoUrl)).status, 200);
});
test('demo CLO can view only demo photos', async () => {
  const restricted = setup({uid: 'clo', extra: {role: 'clo', isDemo: true}, report: {photoUrl}});
  assert.equal((await restricted.download(photoUrl)).status, 403);
  const demo = setup({uid: 'clo', extra: {role: 'clo', isDemo: true}, report: {demo: true, photoUrl}});
  assert.equal((await demo.download(photoUrl)).status, 200);
});
test('unrecorded image address cannot disclose an asset', async () => {
  const app = setup({report: {photoUrl: photoUrl.replace(hash, 'b'.repeat(64))}});
  assert.equal((await app.download(photoUrl)).status, 404);
});
test('missing report and upstream image failure are explicit', async () => {
  assert.equal((await setup().download(photoUrl)).status, 404);
  assert.equal((await setup({report: {photoUrl}, downloadFails: true}).download(photoUrl)).status, 502);
});
test('browser origins are restricted and preflight is supported', async () => {
  const app = setup();
  assert.equal((await app.worker.fetch(new Request('https://photos.example/reports/report-1/photo', {method: 'OPTIONS', headers: {Origin: 'https://evil.example'}}), environment)).status, 403);
  const response = await app.worker.fetch(new Request('https://photos.example/reports/report-1/photo', {method: 'OPTIONS', headers: {Origin: 'https://app.example'}}), environment);
  assert.equal(response.status, 204); assert.equal(response.headers.get('Access-Control-Allow-Origin'), 'https://app.example');
});
test('invalid path and absent configuration fail closed', async () => {
  const app = setup();
  assert.equal((await app.worker.fetch(new Request('https://photos.example/no-such-path'), environment)).status, 404);
  assert.equal((await app.upload({env: {CLOUDINARY_API_SECRET: ''}})).status, 503);
});
test('signature canonicalizes keys and never returns the secret', async () => {
  assert.equal(await signCloudinary({b: 2, a: 1}, 'secret'), await signCloudinary({a: 1, b: 2}, 'secret'));
  assert.match(await signCloudinary({a: 1}, 'secret'), /^[a-f0-9]{40}$/);
});
