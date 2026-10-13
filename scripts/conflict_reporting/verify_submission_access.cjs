/** Live rules regression check. Creates a labelled temporary report and two
 * temporary users, then removes them. Never prints credentials or sends alerts.
 * Run after refreshing the Firebase CLI login and setting FIREBASE_CLI_ROOT. */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {configstore} = require(path.join(process.env.FIREBASE_CLI_ROOT, 'lib/configstore.js'));
const oauth = configstore.get('tokens').access_token;
const key = fs.readFileSync('lib/firebase_options.dart', 'utf8').match(/apiKey: '([^']+)'/)[1];
const root = 'projects/wildora-138e3/databases/(default)/documents';
const base = `https://firestore.googleapis.com/v1/${root}`;
async function auth(action, body) {
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${action}?key=${key}`, {
    method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body),
  });
  const data = await response.json();
  if (!response.ok) throw Error(`Authentication check failed: ${response.status}`);
  return data;
}
function headers(token) { return {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json'}; }
function fields(data) {
  return Object.fromEntries(Object.entries(data).map(([name, value]) => [name,
    typeof value === 'boolean' ? {booleanValue: value} : typeof value === 'number'
      ? {doubleValue: value} : {stringValue: value},
  ]));
}
async function status(response, expected, description) {
  if (response.status !== expected) throw Error(`${description}: expected ${expected}, got ${response.status}`);
  console.log(`Verified ${description}.`);
}
(async () => {
  const users = [];
  const id = `submission-rules-test-${crypto.randomBytes(8).toString('hex')}`;
  const url = `${base}/conflictReports/${id}`;
  let created = false;
  try {
    users.push(await auth('signUp', {returnSecureToken: true}));
    users.push(await auth('signUp', {returnSecureToken: true}));
    const [owner, other] = users;
    await status(await fetch(url), 403, 'unauthenticated unused-ID lookup denied');
    await status(await fetch(url, {headers: headers(owner.idToken)}), 404, 'signed-in unused-ID lookup allowed');
    const now = new Date().toISOString();
    const report = {id, reporterId: owner.localId, isDemo: false,
      referenceNumber: `TEMP-${id}`, description: '[TEMPORARY TEST ONLY] Not an actual incident; deleted after the check.',
      wildlifeType: 'elephant', conflictType: 'cropRaiding', latitude: 7.291, longitude: 80.635,
      locationDescription: '[TEMPORARY TEST ONLY] Test coordinates', createdAt: now, updatedAt: now,
      syncStatus: 'synced', reportStatus: 'submitted', notificationStatus: 'suppressedTest', photoDeliveryStatus: 'none'};
    const creation = await fetch(`${base}/conflictReports?documentId=${id}`, {
      method: 'POST', headers: headers(owner.idToken),
      body: JSON.stringify({fields: fields(report)}),
    });
    if (!creation.ok) throw Error(`Report create failed: ${creation.status}`);
    created = true;
    console.log('Verified report creation after the authenticated unused-ID lookup.');
    await status(await fetch(url, {headers: headers(owner.idToken)}), 200, 'owner can read the accepted report for a retry');
    await status(await fetch(url, {headers: headers(other.idToken)}), 403, 'another member cannot read the existing report');
    await status(await fetch(url), 403, 'unauthenticated existing-report access denied');
  } finally {
    if (created) {
      const deletion = await fetch(url, {method: 'DELETE', headers: headers(oauth)});
      if (!deletion.ok) throw Error(`Temporary report cleanup failed: ${deletion.status}`);
    }
    for (const user of users) await auth('delete', {idToken: user.idToken});
    console.log('Temporary verification data removed.');
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
