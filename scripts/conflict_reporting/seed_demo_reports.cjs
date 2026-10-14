/** Create-only demo seeding. Uses the existing Firebase CLI login; never prints
 * credentials, overwrites reports, or invokes a notification service. */
const fs = require('node:fs');
const path = require('node:path');
const project = 'wildora-138e3';
const now = '2026-10-09T12:00:00.000Z';
const reports = [
  ['demo-hwc-001', 'elephant', 'cropRaiding', 'submitted', 7.291, 80.635, 'Kandy farmland (fictional incident)'],
  ['demo-hwc-002', 'wildBoar', 'propertyDamage', 'underReview', 6.9271, 79.8612, 'Colombo garden (fictional incident)'],
  ['demo-hwc-003', 'leopard', 'animalSighting', 'resolved', 6.476, 80.891, 'Udawalawe boundary (fictional incident)'],
].map(([id, wildlifeType, conflictType, reportStatus, latitude, longitude, locationDescription]) => ({
  id, referenceNumber: `DEMO-HWC-${id.slice(-3)}`, wildlifeType, conflictType,
  description: '[DEMO — NOT A REAL INCIDENT] Sample report for testing the conflict reporting workflow.',
  latitude, longitude, locationDescription: `[DEMO] ${locationDescription}`,
  createdAt: now, updatedAt: now, photoPath: null, photoUrl: null,
  photoContentType: null, reportStatus, syncStatus: 'synced', isDemo: true,
  notificationStatus: 'suppressedDemo', assignmentStatus: 'demoOnly',
  reviewedBy: reportStatus === 'submitted' ? null : 'Demo CLO (fictional)',
  reviewedAt: reportStatus === 'submitted' ? null : now,
  resolvedAt: reportStatus === 'resolved' ? now : null,
  responseNotes: reportStatus === 'resolved' ? '[DEMO] Sample response recorded; no actual dispatch occurred.' : null,
}));
function field(value) {
  if (value === null) return {nullValue: null};
  if (typeof value === 'boolean') return {booleanValue: value};
  if (typeof value === 'number') return {doubleValue: value};
  return {stringValue: value};
}
async function main() {
  const cliRoot = process.env.FIREBASE_CLI_ROOT;
  if (!cliRoot) throw new Error('Set FIREBASE_CLI_ROOT to the installed firebase-tools package directory.');
  const {configstore} = require(path.join(cliRoot, 'lib/configstore.js'));
  const token = configstore.get('tokens')?.access_token;
  if (!token) throw new Error('Run firebase login before seeding.');
  const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
  const headers = {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json'};
  for (const report of reports) {
    const url = `${base}/conflictReports/${report.id}`;
    const existing = await fetch(url, {headers});
    if (existing.ok) { console.log(`Preserved existing ${report.id}`); continue; }
    if (existing.status !== 404) throw new Error(`Access check failed: HTTP ${existing.status}`);
    const response = await fetch(`${base}:commit`, {method: 'POST', headers,
      body: JSON.stringify({writes: [{
        update: {name: `projects/${project}/databases/(default)/documents/conflictReports/${report.id}`,
          fields: Object.fromEntries(Object.entries(report).map(([key,value]) => [key,field(value)]))},
        currentDocument: {exists: false},
      }]}),
    });
    if (!response.ok) throw new Error(`Could not create ${report.id}: HTTP ${response.status}`);
    console.log(`Created ${report.id} (${report.reportStatus}; demo notifications suppressed)`);
    const verify = await fetch(url, {headers});
    if (!verify.ok) throw new Error(`Verification failed for ${report.id}`);
    const saved = await verify.json();
    if (saved.fields?.isDemo?.booleanValue !== true) throw new Error('Demo marker verification failed');
  }
  const cache = '/tmp/wildora-demo-reports';
  fs.mkdirSync(cache, {recursive: true});
  for (const report of reports) fs.writeFileSync(path.join(cache, `${report.id}.json`), JSON.stringify(report));
  console.log('Verified 3 demo documents. Device-cache snapshots prepared in /tmp/wildora-demo-reports.');
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
