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
 const checkedIn=fs.readFileSync('firestore.rules','utf8');
 const featureBegin=checkedIn.indexOf('    // Conflict reporting only;');
 const featureEnd=checkedIn.indexOf('    // Deny all other paths', featureBegin);
 if(featureBegin<0 || featureEnd<0)throw Error('Reviewed conflict-report rules block missing');
 const feature=checkedIn.slice(featureBegin,featureEnd);

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
