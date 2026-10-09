const fs=require('node:fs');
const {configstore}=require(require('node:path').join(process.env.FIREBASE_CLI_ROOT, 'lib/configstore.js'));
const headers={Authorization:`Bearer ${configstore.get('tokens').access_token}`,'Content-Type':'application/json'};
const project='projects/wildora-138e3';
async function api(path,method='GET',body){const r=await fetch('https://firebaserules.googleapis.com/v1/'+path,{method,headers,...(body?{body:JSON.stringify(body)}:{})});const v=await r.json();if(!r.ok)throw Error(`Rules API ${r.status}: ${v.error?.message}`);return v;}
(async()=>{
 const release=await api(project+'/releases/cloud.firestore');
 const live=await api(release.rulesetName);
 fs.writeFileSync('.firebase/conflict-reporting/firestore-before.json',JSON.stringify(live));
 const source=live.source.files.find(f=>f.name==='firestore.rules');
 if(!source)throw Error('Expected live Firestore rules source missing');
 const old='allow read, write: if request.time < timestamp.date(2026, 11, 7);';
 if(!source.content.includes(old) && !source.content.includes('function conflictClo'))throw Error('Live policy changed; refusing to replace it.');
 let content=source.content.replace(old,"allow read, write: if request.time < timestamp.date(2026, 11, 7) && request.path[3] != 'conflictReports';");
 const marker='    match /{document=**}';
 const feature="    // Conflict reporting only; other collections retain their existing policy.\n    function conflictClo() {\n      return request.auth != null && request.auth.token.get('role', '') == 'clo';\n    }\n    match /conflictReports/{reportId} {\n      allow read: if request.auth != null && ((conflictClo() &&\n        (!request.auth.token.get('isDemo', false) || resource.data.get('isDemo', false))) ||\n        resource.data.get('isDemo', false) == true ||\n        resource.data.get('reporterId', '') == request.auth.uid);\n      allow create: if request.auth != null &&\n        request.resource.data.id == reportId &&\n        request.resource.data.reporterId == request.auth.uid &&\n        request.resource.data.get('isDemo', false) == request.auth.token.get('isDemo', false) &&\n        request.resource.data.syncStatus == 'synced' &&\n        request.resource.data.reportStatus == 'submitted' &&\n        request.resource.data.description is string &&\n        request.resource.data.description.size() > 0 && request.resource.data.description.size() <= 500 &&\n        request.resource.data.latitude is number && request.resource.data.latitude >= -90 && request.resource.data.latitude <= 90 &&\n        request.resource.data.longitude is number && request.resource.data.longitude >= -180 && request.resource.data.longitude <= 180 &&\n        request.resource.data.locationDescription is string && request.resource.data.locationDescription.size() > 0 &&\n        request.resource.data.wildlifeType in ['elephant', 'leopard', 'wildBoar', 'other'] &&\n        request.resource.data.conflictType in ['cropRaiding', 'animalSighting', 'propertyDamage', 'threatToPeople', 'other'];\n      allow update: if conflictClo() &&\n        (!request.auth.token.get('isDemo', false) || resource.data.get('isDemo', false)) &&\n        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['reportStatus', 'reviewedBy', 'reviewedAt', 'resolvedAt', 'responseNotes', 'updatedAt']) &&\n        ((resource.data.reportStatus == 'submitted' && request.resource.data.reportStatus == 'underReview') ||\n         (resource.data.reportStatus == 'underReview' && request.resource.data.reportStatus == 'resolved' &&\n          request.resource.data.responseNotes is string && request.resource.data.responseNotes.size() > 0));\n      allow delete: if false;\n    }\n\n\n";
 if(!content.includes(marker))throw Error('Live wildcard marker missing');
 if(content.includes('function conflictClo')) {
  const begin=content.indexOf('    // Conflict reporting only;');
  const end=content.indexOf(marker, begin);
  if(begin < 0 || end < 0)throw Error('Cannot isolate existing feature policy safely');
  content=content.slice(0,begin)+feature+'\n'+content.slice(end);
 } else content=content.replace(marker,feature+'\n'+marker);
 fs.writeFileSync('.firebase/conflict-reporting/firestore-proposed.rules',content);
 const created=await api(project+'/rulesets','POST',{source:{files:[{name:'firestore.rules',content}]}});
 const current=await api(project+'/releases/cloud.firestore');
 if(current.rulesetName!==release.rulesetName)throw Error('Another deployment changed the rules; refusing to overwrite it.');
 await api(project+'/releases/cloud.firestore?updateMask=rulesetName','PATCH',{release:{name:project+'/releases/cloud.firestore',rulesetName:created.name}});
 fs.writeFileSync('.firebase/conflict-reporting/firestore-release.json',JSON.stringify({before:release.rulesetName,after:created.name}));
 console.log('Deployed feature-only ownership/CLO rules. Other collection access preserved; prior rules backed up.');
})().catch(e=>{console.error(e.message, e.cause?.code || '', e.cause?.message || '');process.exitCode=1});
