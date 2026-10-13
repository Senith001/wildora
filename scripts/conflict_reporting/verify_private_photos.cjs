/** End-to-end private photo check. Temporary labelled reports, users and cloud
 * assets are removed in finally. Credentials and bearer tokens are never logged. */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {configstore} = require(path.join(process.env.FIREBASE_CLI_ROOT, 'lib/configstore.js'));
const oauth = configstore.get('tokens').access_token;
const key = fs.readFileSync('lib/firebase_options.dart','utf8').match(/apiKey: '([^']+)'/)[1];
const cloCredentials = JSON.parse(fs.readFileSync('.firebase/conflict-reporting/demo-clo.json'));
const cloud = JSON.parse(fs.readFileSync('.firebase/conflict-reporting/cloudinary.json'));
const api = 'https://wildora-conflict-photos.wildora.workers.dev';
const base = 'https://firestore.googleapis.com/v1/projects/wildora-138e3/databases/(default)/documents';
const pixels = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGOYeWbmfwAG/gL+8h1avgAAAABJRU5ErkJggg==','base64');
async function authenticate(action, body) {
 const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${action}?key=${key}`, {
  method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
 const result = await r.json(); if(!r.ok)throw Error(`Authentication ${action}: HTTP ${r.status}`);return result;
}
const headers = token => ({Authorization:'Bearer '+token,'Content-Type':'application/json'});
function fields(data) { return Object.fromEntries(Object.entries(data).map(([k,v])=>[k,v===null?{nullValue:null}:typeof v==='boolean'?{booleanValue:v}:typeof v==='number'?{doubleValue:v}:{stringValue:v}])); }
async function requireStatus(response, expected, description) {
 if(response.status!==expected)throw Error(`${description}: expected ${expected}, got ${response.status}`);
 console.log(`Verified ${description}.`);return response;
}
async function photoUpload(user, id) {
 const r=await fetch(`${api}/reports/${id}/photo`,{method:'POST',headers:{Authorization:'Bearer '+user.idToken,'Content-Type':'image/png'},body:pixels});
 if(!r.ok){const e=await r.json();throw Error(`Private upload: HTTP ${r.status} (${e.error})`);}
 return r.json();
}
async function main() {
 const users=[];const created=[];const assets=new Set();
 const {signCloudinary}=await import('../../services/conflict-photos/src/worker.mjs');
 try {
  const owner=await authenticate('signUp',{returnSecureToken:true});users.push(owner);
  const other=await authenticate('signUp',{returnSecureToken:true});users.push(other);
  const clo=await authenticate('signInWithPassword',{email:cloCredentials.email,password:cloCredentials.password,returnSecureToken:true});
  const id='private-photo-test-'+crypto.randomBytes(6).toString('hex');
  assets.add(`wildora/${owner.localId}/${id}/${crypto.createHash('sha256').update(pixels).digest('hex')}`);
  const uploaded=await photoUpload(owner,id);
  const assetHash=new URL(uploaded.photoUrl).pathname.split('/').at(-1).split('.')[0];
  assets.add(`wildora/${owner.localId}/${id}/${assetHash}`);
  const repeated=await photoUpload(owner,id);
  if(repeated.photoUrl!==uploaded.photoUrl)throw Error('Retry created another photo reference');
  console.log('Verified private Cloudinary upload and stable reference on retry.');
  const now=new Date().toISOString();
  const report={id,referenceNumber:'DEMO-PRIVATE-PHOTO-TEST',reporterId:owner.localId,isDemo:false,
   description:'[TEMPORARY DEMO TEST ONLY] Private photo access verification; not a real incident.',
   wildlifeType:'elephant',conflictType:'animalSighting',latitude:7.291,longitude:80.635,
   locationDescription:'[TEMPORARY DEMO TEST] Test coordinates',createdAt:now,updatedAt:now,
   syncStatus:'synced',reportStatus:'submitted',photoDeliveryStatus:'uploaded',photoUrl:uploaded.photoUrl};
  await requireStatus(await fetch(`${base}/conflictReports?documentId=${id}`,{method:'POST',headers:headers(owner.idToken),body:JSON.stringify({fields:fields(report)})}),200,'report records the private photo reference');
  created.push(id);
  const image=await requireStatus(await fetch(uploaded.photoUrl,{headers:{Authorization:'Bearer '+owner.idToken}}),200,'reporter can view private image');
  if(!image.headers.get('Content-Type').startsWith('image/')||!(await image.arrayBuffer()).byteLength)throw Error('Image bytes missing');
  await requireStatus(await fetch(uploaded.photoUrl),401,'unauthenticated photo access denied');
  await requireStatus(await fetch(uploaded.photoUrl,{headers:{Authorization:'Bearer '+other.idToken}}),403,'unrelated reporter photo access denied');
  await requireStatus(await fetch(uploaded.photoUrl,{headers:{Authorization:'Bearer '+clo.idToken}}),403,'demo CLO cannot view real-report evidence');
  await requireStatus(await fetch(`${base}/conflictReports/${id}?updateMask.fieldPaths=isDemo`,{method:'PATCH',headers:headers(oauth),body:JSON.stringify({fields:fields({isDemo:true})})}),200,'temporary fixture explicitly classified as demo');
  await requireStatus(await fetch(uploaded.photoUrl,{headers:{Authorization:'Bearer '+clo.idToken}}),200,'authorized demo CLO can view demo image');
  await requireStatus(await fetch(uploaded.photoUrl,{headers:{Authorization:'Bearer '+other.idToken}}),403,'demo record visibility does not make its photo public');
  const direct=await fetch(`https://res.cloudinary.com/${cloud.cloudName}/image/authenticated/${[...assets][0]}.png`);
  if(direct.ok)throw Error('Unsigned Cloudinary address exposed private asset');
  console.log('Verified unsigned Cloudinary address cannot reveal the image.');

  const legacyId='private-photo-legacy-test-'+crypto.randomBytes(6).toString('hex');
  const legacy={...report,id:legacyId,photoUrl:null,photoDeliveryStatus:'deviceOnly'};
  await requireStatus(await fetch(`${base}/conflictReports?documentId=${legacyId}`,{method:'POST',headers:headers(owner.idToken),body:JSON.stringify({fields:fields(legacy)})}),200,'legacy device-only fixture created');created.push(legacyId);
  assets.add(`wildora/${owner.localId}/${legacyId}/${crypto.createHash('sha256').update(pixels).digest('hex')}`);
  const delivered=await photoUpload(owner,legacyId);
  const hash=new URL(delivered.photoUrl).pathname.split('/').at(-1).split('.')[0];assets.add(`wildora/${owner.localId}/${legacyId}/${hash}`);
  await requireStatus(await fetch(`${base}/conflictReports/${legacyId}?updateMask.fieldPaths=photoUrl&updateMask.fieldPaths=photoDeliveryStatus`,{method:'PATCH',headers:headers(owner.idToken),body:JSON.stringify({fields:fields({photoUrl:delivered.photoUrl,photoDeliveryStatus:'uploaded'})})}),200,'owner can deliver a previously device-only attachment');
  await requireStatus(await fetch(`${base}/conflictReports/${legacyId}?updateMask.fieldPaths=reportStatus`,{method:'PATCH',headers:headers(owner.idToken),body:JSON.stringify({fields:fields({reportStatus:'resolved'})})}),403,'photo permission does not allow changing CLO workflow');
 } finally {
  let cleanupFailed=false;
  for(const id of created) {const r=await fetch(`${base}/conflictReports/${id}`,{method:'DELETE',headers:headers(oauth)});if(!r.ok)cleanupFailed=true;}
  for(const publicId of assets) {
   const parameters={public_id:publicId,type:'authenticated',timestamp:Math.floor(Date.now()/1000)};
   const form=new URLSearchParams({...parameters,api_key:cloud.apiKey,signature:await signCloudinary(parameters,cloud.apiSecret)});
   const r=await fetch(`https://api.cloudinary.com/v1_1/${cloud.cloudName}/image/destroy`,{method:'POST',body:form});if(!r.ok)cleanupFailed=true;
  }
  for(const user of users)try{await authenticate('delete',{idToken:user.idToken});}catch{cleanupFailed=true;}
  if(cleanupFailed)throw Error('One or more temporary verification items could not be removed');
  console.log('Temporary reports, users and private images removed.');
 }
}
main().catch(error=>{console.error(error.message);process.exitCode=1});
