const assert=require('node:assert/strict');
const path=require('node:path');
const {JSDOM,VirtualConsole}=require('jsdom');
let passed=0;
const modules={case:{write:true,subject:true},warrant:{write:true,subject:true},incident:{write:true,subject:true},document:{write:true},note:{write:true,private:true},vehicle_flag:{write:true},weapon:{write:true},business_license:{write:true},business_note:{write:true},recording:{write:true}};
const base={citizenid:'STAFF',name:'Test Judge',job:'doj',label:'Crimson Justice',department:'doj',grade:3,canWrite:true,canManage:true,onduty:true,modules,counts:[{kind:'case',status:'open',total:2}],recent:[],threat:'green',integrations:{inventory:false,cameras:false,bodycam:false,banking:false,jail:false}};
const citizen={citizenid:'CID001',firstname:'Test',lastname:'Citizen',birthdate:'1990-01-01',nationality:'Test'};
const record={id:7,kind:'case',title:'<img src=x onerror=alert(1)>',subject:'CID001',body:'Evidence narrative',owner:'STAFF',updated_by:'STAFF',status:'open',version:1,details:{charges:'Test charge'}};
let bootstrap={...base},lastRequest,rows=[record],calls=[];
const check=(v,msg)=>{assert.ok(v,msg);passed++;};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const errors=[];const console=new VirtualConsole();console.on('jsdomError',e=>errors.push(e.message));
 const dom=await JSDOM.fromFile(path.join(__dirname,'../crimson_doj/web/index.html'),{runScripts:'dangerously',resources:'usable',virtualConsole:console,beforeParse(w){
  w.GetParentResourceName=()=> 'crimson_doj';w.confirm=()=>true;
  w.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','');};w.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open');};
  w.fetch=async(url,opts)=>{const data=JSON.parse(opts.body);lastRequest=data;calls.push(data);let result;
   if(data.action==='bootstrap')result=bootstrap;
   if(data.action==='search')result=[citizen];
   if(data.action==='profile')result={person:citizen,records:[record]};
   if(data.action==='list')result={rows:rows.filter(x=>x.kind===data.payload.kind),total:rows.filter(x=>x.kind===data.payload.kind).length,page:data.payload.page||1};
   if(data.action==='create'||data.action==='update')result={id:9};
   if(data.action==='employees')result={rows:[{citizenid:'OTHER',firstname:'Other',lastname:'Staff',grade:1,online:true,duty:true}],grades:[{level:0,name:'Assistant'},{level:1,name:'Lawyer'},{level:3,name:'Judge'}]};
   if(data.action==='audit')result={rows:[{id:1,actor:'STAFF',action:'create_case',record_id:7}],total:1,page:1};
   if(data.action==='roster')result=[{id:1,citizenid:'STAFF',name:'Test Judge',job:'doj',grade:3,status:'available'}];
   if(data.action==='businesses')result=[{job:'mechanic',label:'Mechanic',licenses:[]}];
   if(data.action==='penalcode')result=[];
   if(data.action==='equipment')result={integrations:bootstrap.integrations,cameras:[],kits:[]};
   if(data.action==='vehicles')result=[{plate:'ABC123',vehicle:'sultan',citizenid:'CID001'}];
   if(data.action==='duty'){bootstrap={...bootstrap,onduty:data.payload.enabled};result=true;}
   return {ok:true,json:async()=>({ok:true,data:result})};
  };
 }});
 const w=dom.window,d=w.document,$=s=>d.querySelector(s);
 async function wait(fn,label){for(let i=0;i<100;i++){if(fn())return;await sleep(15);}throw Error('Timed out '+label);}
 await wait(()=>typeof w.nui==='function','app load');
 async function open(data){bootstrap=data;w.postMessage({action:'open',data},'*');await wait(()=>!$('#tablet').hidden&&$('#heading').textContent==='Dashboard','tablet');await sleep(60);}
 async function nav(key){const b=$(`[data-view="${key}"]`);check(!!b,'navigation '+key);b.click();await sleep(60);}
 await open(base);
 check($('#name').textContent==='Test Judge','operator identity');check($('#content').textContent.includes('Active department records'),'dashboard stats');check(!$('#content').textContent.includes('undefined'),'no undefined labels');
 await nav('citizens');$('input').value='Test';$('form.toolbar').dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));await sleep(60);
 check($('#content').textContent.includes('Test Citizen'),'citizen search');[...d.querySelectorAll('#content button')].find(x=>x.textContent==='Open profile').click();await sleep(60);
 check($('#content').textContent.includes('CID001'),'citizen profile');check(!$('#content img'),'stored HTML not interpreted');
 [...d.querySelectorAll('#content button')].find(x=>x.textContent==='View').click();await sleep(30);check($('#content').textContent.includes('<img src=x'),'record title rendered as text');
 [...d.querySelectorAll('#content button')].find(x=>x.textContent==='Edit record').click();await sleep(30);check($('#editor').open,'edit dialog opens');check($('#editor-fields textarea').value==='Evidence narrative','existing body in editor');$('#cancel').click();check(!$('#editor').open,'cancel closes dialog');
 await nav('case');[...d.querySelectorAll('#content button')].find(x=>x.textContent.startsWith('+ New')).click();await sleep(20);const inputs=$('#editor-fields').querySelectorAll('input');inputs[0].value='New case';inputs[1].value='CID001';$('#editor-fields textarea').value='New evidence';$('#edit-form').dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));await sleep(70);check(calls.some(x=>x.action==='create'&&x.payload.subject==='CID001'&&x.payload.title==='New case'),'create payload');check(!$('#editor').open,'save closes dialog');
 await nav('archive');check(lastRequest.action==='list'&&lastRequest.payload.archived===true,'archive server filter requested');
 await nav('employees');check($('#content').textContent.includes('Other Staff'),'employee roster');[...d.querySelectorAll('#content button')].find(x=>x.textContent==='Manage').click();await sleep(20);check(![...$('#editor-fields select').options].some(o=>o.value==='3'),'equal grade not offered');$('#cancel').click();
 await nav('roster');check($('#content').textContent.includes('AVAILABLE'),'unit roster');
 await nav('businesses');check($('#content').textContent.includes('Grant license'),'business registry action');
 await nav('audit');check($('#content').textContent.includes('create_case'),'audit view');
 await nav('equipment');check($('#content').textContent.includes('NOT CONFIGURED'),'disabled integrations explicit');
 await nav('penalcode');check($('#content').textContent.includes('No laws configured'),'no invented laws');
 await open({...base,department:'ems',job:'ambulance',label:'Crimson Medical',modules:{medical:{write:true,subject:true},document:{write:true},note:{write:true},dispatch:{write:true},recording:{write:true}},counts:[]});
 check(!$('[data-view="case"]'),'legal cases hidden from EMS');check(!$('[data-view="businesses"]'),'business registry hidden from EMS');check(!!$('[data-view="medical"]'),'medical module available');
 await open({...base,department:'business',job:'mechanic',label:'Mechanic',modules:{invoice:{write:true},product:{write:true},document:{write:true},note:{write:true}},counts:[]});
 check(!$('[data-view="roster"]'),'business has no units');check(!$('[data-view="medical"]'),'business has no medical module');await nav('invoice');check($('#subtitle').textContent.includes('payment integration not configured'),'billing limitation visible');
 await open({...base,onduty:false});check($('#content').textContent.includes('You are off duty'),'off duty access screen');await nav('case');check($('#content').textContent.includes('Clock in first'),'off duty records blocked in UI');
 $('#duty').click();await sleep(70);check(calls.some(x=>x.action==='duty'&&x.payload.enabled===true),'duty toggle callback');
 $('#close').click();await sleep(30);check($('#tablet').hidden,'tablet closes');
 check(errors.length===0,'zero DOM runtime exceptions: '+errors.join('; '));dom.window.close();process.stdout.write(`PASS ${passed} UI checks across DOJ, EMS, Business, safe rendering, forms and duty\n`);process.exit(0);
})().catch(e=>{process.stderr.write(e.stack+'\n');process.exit(1);});
