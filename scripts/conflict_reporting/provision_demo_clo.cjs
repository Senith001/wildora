/** Provision a fictional CLO account using the existing project administrator
 * login. Credentials stay in an ignored, owner-readable local file. */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
async function main() {
  const root = process.env.FIREBASE_CLI_ROOT;
  if (!root) throw new Error('Set FIREBASE_CLI_ROOT.');
  const token = require(path.join(root, 'lib/configstore.js')).configstore.get('tokens')?.access_token;
  if (!token) throw new Error('Run firebase login first.');
  const project = 'wildora-138e3';
  const headers = {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json'};
  async function api(url, method, body) {
    const response = await fetch(url, {method, headers, ...(body ? {body: JSON.stringify(body)} : {})});
    const result = await response.json();
    if (!response.ok) throw new Error(`Firebase account setup failed: HTTP ${response.status}; ${result.error?.message || 'request rejected'}`);
    return result;
  }
  const file = '.firebase/conflict-reporting/demo-clo.json';
  if (fs.existsSync(file)) { console.log('Existing demo CLO credentials preserved.'); return; }
  const configUrl = `https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config`;
  await api(configUrl, 'GET');
  await api(configUrl+'?updateMask=signIn.email.enabled,signIn.email.passwordRequired,signIn.anonymous.enabled', 'PATCH', {
    signIn: {email: {enabled: true, passwordRequired: true}, anonymous: {enabled: true}},
  });
  const credentials = {email: 'demo-clo@wildora.example', password: crypto.randomBytes(24).toString('base64url')+'!aA7'};
  const account = await api('https://identitytoolkit.googleapis.com/v1/accounts:signUp', 'POST', {
    targetProjectId: project, email: credentials.email, password: credentials.password,
    displayName: 'Demo CLO — fictional training account', localId: 'wildora-demo-clo',
  });
  // Save before claiming the role so a subsequent failure never loses the password.
  fs.mkdirSync(path.dirname(file), {recursive: true, mode: 0o700});
  fs.writeFileSync(file, JSON.stringify({...credentials, uid: account.localId, isDemo: true}, null, 2), {mode: 0o600});
  await api('https://identitytoolkit.googleapis.com/v1/accounts:update', 'POST', {
    targetProjectId: project, localId: account.localId,
    customAttributes: JSON.stringify({role: 'clo', isDemo: true}),
  });
  console.log('Created demo CLO with role claim. Credentials are in ignored .firebase/conflict-reporting/demo-clo.json.');
}
main().catch(error => {console.error(error.message); process.exitCode = 1;});
