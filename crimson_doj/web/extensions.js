'use strict';
modules.document.fields.push(['signers','Signer citizen IDs (comma separated)','text']);
const extLines=value=>String(value||'').split(/[\n,]+/).map(s=>s.trim()).filter(Boolean);
function extForm(title,specs,save,help=''){
 clearError();$('#editor-title').textContent=title;const fields=$('#editor-fields');fields.replaceChildren();const inputs={};
 if(help)fields.append(node('div',help,'info'));
 for(const spec of specs){const f=field(spec.label,spec.type==='multi'?'select':spec.type||'text',spec.value??'',spec.options);if(spec.type==='multi'){f.input.multiple=true;f.input.size=8;}if(spec.required)f.input.required=true;inputs[spec.key]=f.input;fields.append(f.label);}
 $('#edit-form').onsubmit=async event=>{event.preventDefault();$('#save').disabled=true;try{const data={};for(const [k,input]of Object.entries(inputs))data[k]=input.multiple?Array.from(input.selectedOptions).map(o=>o.value):input.type==='number'?Number(input.value):input.value;await save(data);dialog.close();}catch(e){error(e);}finally{$('#save').disabled=false;}};
 dialog.showModal();
}
function extBool(key,label,value){return {key,label,type:'select',value:value?'yes':'no',options:[{value:'no',label:'No'},{value:'yes',label:'Yes'}]};}
function extNav(group,key,label,icon){
 const navNode=$('#nav'),heads=Array.from(navNode.querySelectorAll('.nav-group'));let heading=heads.find(n=>n.textContent===group);
 if(!heading){heading=node('div',group,'nav-group');navNode.append(heading);}
 let next=heading.nextElementSibling;while(next&&!next.classList.contains('nav-group'))next=next.nextElementSibling;
 const b=button('',()=>show(key));b.dataset.view=key;b.append(node('span',icon,'icon'),node('span',label));navNode.insertBefore(b,next);
}
const extOriginalNav=nav;
nav=function(){extOriginalNav();extNav('OVERVIEW','statistics','Statistics','▥');if(session.department==='doj'||session.department==='police'){extNav('OPERATIONS','tracking','Tracking bands','⌖');}if(session.management!==false)extNav('MANAGEMENT','physicalArchive','Document archive','▣');};
const extOriginalShow=show;
show=async function(next,clear=true){
 if(!['statistics','tracking','physicalArchive'].includes(next))return extOriginalShow(next,clear);
 view=next;try{if(!session?.onduty)throw Error('Go on duty first');if(next==='statistics')return await extStatistics();if(next==='tracking')return await extTracking();return await extArchive();}catch(e){error(e);}
};
const extOriginalProfile=profile;
profile=async function(cid){
 const loading=extOriginalProfile(cid);const seq=sequence;await loading;if(seq!==sequence||profileId!==cid)return;const extra=await request('citizenExtra',{citizenid:cid});if(seq!==sequence||profileId!==cid)return;
 const data=extra.data||{},p=panel('Full citizen file','Department annotations and verified Qbox licenses'),body=node('div',undefined,'panel-body');
 if(data.photo)body.append(documentImage(data.photo));body.append(node('p','Phone: '+(extra.phone||'Not recorded')));
 const wanted=data.wanted||(extra.warrants||[]).length>0;body.append(badge(wanted?'WANTED / ACTIVE WARRANT':'NO ACTIVE WANTED FLAG'),node('p',data.wantedReason||''),node('p',data.notes||'No department profile notes'));
 body.append(extNoteHistory(extra.notesHistory||[]));
 if(extra.canEdit)body.append(button('Add citizen note',()=>extNoteForm('addCitizenNote',{citizenid:cid},()=>profile(cid))));
 if(extra.canEdit)body.append(button('Edit citizen file',()=>extForm('Citizen file',[
  {key:'photo',label:'Mugshot URL',type:'url',value:data.photo},extBool('wanted','Wanted',data.wanted),{key:'wantedReason',label:'Wanted reason',value:data.wantedReason},{key:'notes',label:'Profile notes',type:'textarea',value:data.notes}
 ],async values=>{await request('saveCitizenExtra',{...values,wanted:values.wanted==='yes',citizenid:cid,version:extra.version});await profile(cid);},'Changes department annotations, not the character legal identity.')));
 if(extra.licenses){
  body.append(node('h3','Licenses'));for(const [key,value]of Object.entries(extra.licenses))body.append(badge(key+': '+(value?'active':'not active')));
  if(extra.canLicense)body.append(button('Manage license',()=>extForm('Citizen license',[
   {key:'license',label:'License',type:'select',options:extra.licenseTypes||['driver','weapon','business']},extBool('enabled','Granted',true)
  ],async values=>{await request('setCitizenLicense',{...values,enabled:values.enabled==='yes',citizenid:cid});await profile(cid);})))
 }
 if(extra.convictions){
  body.append(node('h3','Conviction history'));
  body.append(table(['OFFENSES','FINE','MONTHS','CASE','DATE'],extra.convictions.map(r=>[(r.data.offenses||[]).map(x=>x.title).join(', '),currency(r.data.fine),r.data.months,r.data.caseId||'—',stamp(r.updated_at)])));
  if(extra.canLicense)body.append(button('Record conviction',async()=>{
   const laws=await request('penalcode');
   if(!laws.length)throw Error('Configure the penal code first');
   extForm('Record conviction',[
    {key:'codes',label:'Offenses (Ctrl/Shift to select several)',type:'multi',options:laws.map(l=>({value:l.code,label:l.code+' · '+l.title+' · '+currency(l.fine)+' / '+l.months+' months'}))},
    {key:'caseId',label:'Linked case ID (optional)',type:'number'},{key:'reason',label:'Judgment / reason',type:'textarea'}
   ],async values=>{await request('recordConviction',{...values,citizenid:cid});await profile(cid);},'Records the legal judgment. It does not debit money or jail automatically; use the case legal actions for enforcement.');
  }));
 }
 p.append(body);content.append(p);
};
vehicles=function(){
 reset('Vehicle search','Search registered plates and their department files');const form=node('form',undefined,'toolbar'),input=node('input');input.placeholder='Plate';const submit=node('button','Search');submit.type='submit';form.append(input,submit);content.append(form);
 form.onsubmit=async event=>{event.preventDefault();try{const rows=await request('vehicles',{query:input.value});content.querySelector('.vehicle-results')?.remove();const box=node('div',undefined,'vehicle-results');box.append(table(['PLATE','OWNER','MODEL',''],rows.map(v=>[v.plate,v.citizenid,v.vehicle,button('Vehicle file',()=>extVehicle(v.plate),'table-action')])));content.append(box);}catch(e){error(e);}};
};
async function extVehicle(plate){
 const token=reset('Vehicle '+plate,'Wanted status, image, owner and notes');const extra=await request('vehicleExtra',{plate});if(token!==sequence)return;
 const data=extra.data||{},body=node('div',undefined,'panel-body'),p=panel(plate,'Owner '+extra.vehicle.citizenid);
 body.append(badge(data.wanted?'WANTED':'NO WANTED FLAG'),node('p',data.reason||''),node('p',data.notes||'No notes'));if(data.photo)body.append(documentImage(data.photo));
 body.append(extNoteHistory(extra.notesHistory||[]));if(extra.canEdit)body.append(button('Add vehicle note',()=>extNoteForm('addVehicleNote',{plate},()=>extVehicle(plate))));
 if(extra.canEdit)body.append(button('Edit vehicle file',()=>extForm('Vehicle file',[
  {key:'photo',label:'Vehicle image URL',type:'url',value:data.photo},extBool('wanted','Wanted',data.wanted),{key:'reason',label:'Wanted reason',value:data.reason},{key:'notes',label:'Notes',type:'textarea',value:data.notes}
 ],async v=>{await request('saveVehicleExtra',{...v,wanted:v.wanted==='yes',plate,version:extra.version});await extVehicle(plate);})));
 body.append(button('Search again',vehicles));p.append(body);content.append(p);
}
const extOriginalDetail=detail;
detail=function(row){
 extOriginalDetail(row);const body=content.querySelector('.panel-body')||content;
 if(['case','incident'].includes(row.kind))body.append(button('Participants, vehicles & evidence',()=>extCase(row),'primary'));
 if(row.kind==='dispatch')body.append(button('Responding units',()=>extDispatch(row),'primary'));
 if(row.kind==='document'){const text=body.querySelector('.entry-body');if(text)text.replaceChildren(extRichText(row.body||''));}
};
async function extCase(record){
 const token=reset('Case file #'+record.id,record.title);const result=await request('caseBundle',{id:record.id});if(token!==sequence)return;
 const data=result.data||{},p=panel('Linked evidence','Structured case participants, registered vehicles and image evidence'),body=node('div',undefined,'panel-body');
 body.append(table(['CITIZEN','ROLE'],(data.participants||[]).map(x=>[x.citizenid,x.role])),node('p','Vehicles: '+(data.vehicles||[]).join(', ')),node('p',data.notes||''));
 for(const url of data.photos||[])body.append(documentImage(url));
 body.append(extNoteHistory(result.notesHistory||[]));if(result.canEdit)body.append(button('Add case note',()=>extNoteForm('addCaseNote',{id:record.id},()=>extCase(record))));
 if(result.canEdit)body.append(button('Edit linked case file',()=>extForm('Linked case file',[
  {key:'participants',label:'Participants: citizen ID | suspect/officer/witness/victim (one per line)',type:'textarea',value:(data.participants||[]).map(x=>x.citizenid+' | '+x.role).join('\n')},
  {key:'vehicles',label:'Registered vehicle plates (one per line)',type:'textarea',value:(data.vehicles||[]).join('\n')},
  {key:'photos',label:'Evidence image URLs (one per line)',type:'textarea',value:(data.photos||[]).join('\n')},{key:'notes',label:'Case notes',type:'textarea',value:data.notes}
 ],async v=>{await request('saveCaseBundle',{id:record.id,version:result.version,participants:extLines(v.participants).map(x=>{const [citizenid,role]=x.split('|').map(t=>t.trim());return {citizenid,role};}),vehicles:extLines(v.vehicles),photos:String(v.photos).split('\n').map(x=>x.trim()).filter(Boolean),notes:v.notes});await extCase(record);},'All participant IDs and vehicle plates are validated on the server.')));
 body.append(button('Back to case',()=>detail(record)));p.append(body);content.append(p);
}
businesses=async function(){
 const token=reset('Businesses','Discovered Qbox jobs and configured company accounts');const rows=await request('businesses');if(token!==sequence)return;
 const grid=node('div',undefined,'mini-cards');for(const b of rows){const p=node('div',undefined,'mini-card');p.append(node('h3',b.label),node('p',b.job),button('Company file',()=>extBusiness(b),'primary'),button('Bank account',()=>businessBank(b)));if(session.modules.business_license?.write)p.append(button('Grant license',()=>edit('business_license',null,b.job)));grid.append(p);}content.append(grid);
};
async function extBusiness(b){
 const token=reset(b.label+' · company file',b.job);const extra=await request('businessExtra',{job:b.job});if(token!==sequence)return;
 const d=extra.data||{},p=panel(d.label||b.label,d.status||'No legal status recorded'),body=node('div',undefined,'panel-body');if(d.logo)body.append(documentImage(d.logo));body.append(node('p','Owner: '+(d.owner||'Not registered')),node('p',d.notes||''));
 body.append(table(['EMPLOYEE','CITIZEN ID','GRADE'],(extra.employees||[]).map(x=>[x.name,x.citizenid,x.grade])),node('h3','Business licenses'),table(['TITLE','STATUS'],(b.licenses||[]).map(l=>[l.title,l.status])),button('Bank account',()=>businessBank(b)));
 if(extra.canEdit){body.append(button('Edit company file',()=>extForm('Company file',[
  {key:'label',label:'Display name',value:d.label||b.label},{key:'logo',label:'Logo URL',type:'url',value:d.logo},{key:'owner',label:'Owner citizen ID',value:d.owner},{key:'status',label:'Legal status',type:'select',options:['legal','suspicious','closed'],value:d.status||'legal'},{key:'notes',label:'Operational notes',type:'textarea',value:d.notes}
 ],async v=>{await request('saveBusinessExtra',{...v,job:b.job,version:extra.version});await extBusiness(b);})),button('Grant license',()=>edit('business_license',null,b.job)));}
 p.append(body);content.append(p);
}
const extOriginalEmployees=employees;
employees=async function(){
 const loading=extOriginalEmployees();const seq=sequence;await loading;if(!session||seq!==sequence)return;
 content.prepend(button('Employee notes, duty time & suspension',()=>extForm('Select employee',[{key:'citizenid',label:'Employee citizen ID',required:true}],async v=>{await extStaff(v.citizenid);},'Inspect members of your own department.')));
};
async function extStaff(cid){
 const token=reset('Employee file',cid);const extra=await request('staffExtra',{citizenid:cid});if(token!==sequence)return;
 const p=panel(cid,extra.suspended?'SUSPENDED':'ACTIVE'),body=node('div',undefined,'panel-body');body.append(node('p','Badge number: '+(extra.badgeNumber||'Not assigned')),node('p','Recorded duty: '+(Number(extra.seconds||0)/3600).toFixed(2)+' hours'),node('p',extra.data?.notes||'No personnel notes'));
 if(hasPermission('employees_manage',session.canManage))body.append(button('Edit notes / suspension',()=>extForm('Employee file',[
  {key:'notes',label:'Personnel notes',type:'textarea',value:extra.data?.notes},{key:'badgeNumber',label:'Employee badge number',value:extra.badgeNumber},extBool('suspended','Suspended from MDT duty',extra.suspended),{key:'reason',label:'Suspension reason'}
 ],async v=>{await request('saveStaffExtra',{...v,suspended:v.suspended==='yes',version:extra.version,citizenid:cid});await extStaff(cid);},'Cannot manage yourself or an equal/higher rank. Suspension is enforced by Crimson; other police resources require their own adapter.')));
 body.append(button('Back to employees',employees));p.append(body);content.append(p);
}
async function extStatistics(){
 const token=reset('Statistics','Department records and measured duty time');const data=await request('statistics');if(token!==sequence)return;
 const p=panel('Department records','Private-note counts are excluded');p.append(table(['TYPE','STATUS','TOTAL'],data.counts.map(x=>[x.kind,x.status,x.total])));content.append(p);
 const arrests=panel('Custody activity','Crimson-enforced jail actions');arrests.append(table(['ACTOR','ACTIONS'],(data.arrests||[]).map(x=>[x.actor,x.total])));content.append(arrests);
 const staff=panel('Report activity','Top authors');staff.append(table(['CITIZEN ID','REPORTS'],data.authors.map(x=>[x.owner,x.total])));content.append(staff);
 const hours=panel('Duty time','Top department totals');hours.append(table(['CITIZEN ID','HOURS'],data.duty.map(x=>[x.citizenid,(Number(x.seconds)/3600).toFixed(2)])));content.append(hours);
}
async function extDispatch(row){
 const token=reset('Responding units','#'+row.id+' · '+row.title);const rows=await request('dispatchUnits',{id:row.id});if(token!==sequence)return;const p=panel('Assigned responses','Self-managed response state');p.append(table(['UNIT','STATUS'],rows.map(x=>[x.data.name,x.data.status])));
 for(const status of ['responding','arrived','clear'])p.append(button(status,async()=>{await request('dispatchRespond',{id:row.id,status});await extDispatch(row);}));content.append(p);
}
async function extTracking(){
 const token=reset('Tracking bands','Case-linked, item-backed suspect tracking');const rows=await request('trackingTargets');if(token!==sequence)return;
 const toolbar=node('div',undefined,'toolbar');toolbar.append(button('Attach tracking band',()=>extForm('Attach tracking band',[{key:'source',label:'Nearby target server ID',type:'number'},{key:'caseId',label:'Case ID matching the target',type:'number'}],async v=>{await request('trackingApply',v);await extTracking();})),button('Remove nearby band',()=>extForm('Remove tracking band',[{key:'source',label:'Nearby target server ID',type:'number'}],async v=>{await request('trackingRemove',v);await extTracking();})));
 content.append(toolbar,table(['CITIZEN','CASE','STATUS',''],rows.map(x=>[x.citizenid,x.case_id,x.online?'Online':'Offline',button('Locate',async()=>{const c=await request('trackingLocate',{citizenid:x.citizenid});await nui('extendedWaypoint',c);})])));
}
async function extArchive(){
 const token=reset('Document archive','Physical copies deposited from inventory at your department printer');const rows=await request('archiveDocuments');if(token!==sequence)return;
 content.append(button('Deposit an inventory copy',async()=>{const items=await request('archiveInventory');extForm('Deposit document',[{key:'slot',label:'Inventory document',type:'select',options:items.map(x=>({value:x.slot,label:x.label}))}],async v=>{await request('archiveDeposit',{slot:Number(v.slot)});await extArchive();});}),table(['COPY','TITLE','DEPOSITED BY',''],rows.map(x=>[x.print_id,x.title,x.deposited_by,button('Retrieve',async()=>{await request('archiveRetrieve',{id:x.print_id});await extArchive();})])));
}
const extOriginalEquipment=equipment;
equipment=async function(){const loading=extOriginalEquipment(),token=sequence;await loading;if(token!==sequence)return;content.append(button('Stock armory, returns & my kits',extArmory,'primary'));};
async function extArmory(){
 const token=reset('Armory stock','Collect and return registered equipment at your armory');const data=await request('armoryCatalog');if(token!==sequence)return;
 const stock=Object.fromEntries(data.stock.map(x=>[x.item,x.amount]));const p=panel('Equipment catalog','Only server-configured items can be ordered');const quantities={};let editingKit=null;
 const rows=data.items.map(x=>{const input=node('input');input.type='number';input.min=0;input.max=50;input.value=0;quantities[x.name]=input;return [x.label,x.grade,stock[x.name]||0,input];});p.append(table(['ITEM','GRADE','STOCK','QUANTITY'],rows));
 const items=()=>Object.entries(quantities).filter(([,i])=>Number(i.value)>0).map(([name,i])=>({name,count:Number(i.value)}));
 p.append(button('Collect selected equipment',async()=>{await request('armoryOrder',{items:items()});await extArmory();},'primary'),button('Save selection as my kit',()=>extForm('Save kit',[{key:'label',label:'Kit name',required:true,value:editingKit?.label||''}],async v=>{await request('saveArmoryKit',{label:v.label,items:items(),id:editingKit?.id,version:editingKit?.version});await extArmory();})));
 if(session.canManage)p.append(button('Replenish stock',()=>extForm('Replenish armory',[{key:'item',label:'Catalog item',type:'select',options:data.items.map(x=>({value:x.name,label:x.label}))},{key:'amount',label:'Quantity',type:'number'}],async v=>{await request('armoryStockAdjust',v);await extArmory();})));
 content.append(p);const kits=panel('My equipment kits','Saved catalog selections');for(const row of data.kits){let k;try{k=typeof row.data==='string'?JSON.parse(row.data):row.data;}catch{continue;}kits.append(node('h4',k.label),button('Load / edit selection',()=>{editingKit={id:row.entity_id,version:row.version,label:k.label};for(const input of Object.values(quantities))input.value=0;for(const item of k.items||[])if(quantities[item.name])quantities[item.name].value=item.count;}),button('Collect kit',async()=>{await request('armoryOrder',{items:k.items});await extArmory();}),button('Delete kit',async()=>{await request('deleteArmoryKit',{id:row.entity_id,version:row.version});await extArmory();}));}content.append(kits);
 const returns=await request('armoryReturns');if(token!==sequence)return;content.append(table(['ISSUED ITEM','COUNT',''],returns.map(x=>[x.name,x.count,button('Return equipment',async()=>{await request('armoryReturn',{slot:x.slot});await extArmory();})])));
}
function extRichText(value){
 const root=node('div',undefined,'rich-document');for(const line of String(value).split('\n')){
  const heading=line.match(/^(#{1,3})\s+(.+)$/);const el=node(heading?'h'+(heading[1].length+1):'p');const text=heading?heading[2]:line.replace(/^- /,'• ');
  for(const part of text.split(/(\*\*[^*]+\*\*)/g))el.append(part.startsWith('**')&&part.endsWith('**')?node('strong',part.slice(2,-2)):document.createTextNode(part));root.append(el);
 }return root;
}
const extOriginalEdit=edit;
edit=function(kind,row=null,subject=''){
 extOriginalEdit(kind,row,subject);if(kind!=='document')return;
 const area=$('#editor-fields textarea');if(!area)return;const toolbar=node('div',undefined,'toolbar');
 for(const [label,mark]of [['Heading','# '],['Bold','**'],['Bullet','- ']])toolbar.append(button(label,()=>{const start=area.selectionStart,end=area.selectionEnd,selected=area.value.slice(start,end);area.setRangeText(mark+selected+(mark==='**'?'**':''),start,end,'end');area.focus();}));
 toolbar.append(button('Preview formatted document',()=>{let preview=$('#document-preview');if(!preview){preview=node('div',undefined,'info');preview.id='document-preview';$('#editor-fields').append(preview);}preview.replaceChildren(extRichText(area.value));}));area.parentElement.before(toolbar);
};
window.addEventListener('message',event=>{
 if(event.data?.action!=='document')return;
 const data=event.data.data;const body=$('#printed-body');const imageNode=body.querySelector('.document-image');body.replaceChildren(extRichText(data.body||''));if(imageNode)body.append(imageNode);
 const p=node('section',undefined,'print-signatures');p.append(node('h3','Verified signatures'));
 for(const signature of data.signatures||[])p.append(node('p',signature.signer_name+' · '+stamp(signature.created_at)));
 const signed=(data.signatures||[]).some(s=>s.signer===data.viewerCitizenid);
 if((data.signers||[]).includes(data.viewerCitizenid)&&!signed)p.append(button('Sign this copy as my character',async()=>{const result=await nui('signPrinted');if(!result.ok)throw Error(result.error);p.append(node('p','Signature saved. Reopen the copy to refresh.'));},'primary'));
 if((data.signers||[]).length)body.append(p);
});
const extOriginalEntryList=entryList;
entryList=async function(kind){
 await extOriginalEntryList(kind);if(kind!=='recording')return;
 content.prepend(button('Live bodycams',extLive,'primary'));
};
let extViewer=null;
const liveDialog=node('dialog');liveDialog.id='live-dialog';const liveVideo=node('video');liveVideo.autoplay=true;liveVideo.controls=true;liveVideo.muted=true;liveVideo.style.width='100%';
const disconnectLive=()=>{if(extViewer){extViewer.disconnect();extViewer=null;}liveVideo.srcObject=null;liveDialog.close();};
liveDialog.append(button('Close live view',disconnectLive),node('p','Live game view · video only. The provider does not expose game audio.','info'),liveVideo);document.body.append(liveDialog);liveDialog.addEventListener('cancel',disconnectLive);
async function extLive(){
 const token=reset('Live bodycams','Owners explicitly start their own stream; department-scoped viewer grants');const data=await request('liveSources');if(token!==sequence)return;
 content.append(button('Start my live bodycam',async()=>{await request('liveStart');await extLive();},'primary'),button('Stop my live bodycam',async()=>{await request('liveStop');await extLive();}),button('Refresh streams',extLive));
 if(!data.configured)content.append(node('div','Live video needs the screencapture Cloudflare Worker endpoint and Config.EnableLiveBodycam. Stored recordings continue working without it.','info'));
 content.append(table(['OWNER',''],data.rows.map(row=>[row.name,button('Watch live',async()=>{
  const grant=await request('liveWatch',{citizenid:row.citizenid});disconnectLive();liveDialog.showModal();
  extViewer=new window.CrimsonLiveSDK.ScreenCaptureViewer(grant);await extViewer.connect();await extViewer.attach(liveVideo);
 })])));
}
window.addEventListener('message',event=>{if(event.data?.action==='close')disconnectLive();});

function extNoteHistory(rows){const p=panel('Note history','Append-only department notes');p.append(table(['TITLE','NOTE','AUTHOR','TIME'],rows.map(r=>[r.data.title,r.data.content,r.data.author,stamp(r.updated_at)])));return p;}
function extNoteForm(action,subject,refresh){extForm('Add department note',[{key:'title',label:'Title',required:true},{key:'content',label:'Note',type:'textarea',required:true}],async values=>{await request(action,{...subject,...values});await refresh();});}
