const assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs'),{pathToFileURL}=require('node:url');
const {JSDOM,VirtualConsole}=require('jsdom');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const state={citizenid:'STAFF',name:'Dashboard',job:'doj',label:'Department',department:'doj',grade:14,canWrite:true,canManage:true,management:true,onduty:true,modules:{case:{write:true}},counts:[],recent:[],threat:'green',integrations:{}};
async function run(missing){
 const calls=[],errors=[];let dispose;const vc=new VirtualConsole();vc.on('jsdomError',error=>errors.push(error.message));
 const filename=path.join(__dirname,'../crimson_doj/web/index.html');let html=fs.readFileSync(filename,'utf8');if(missing)html=html.replace('src="i18n.js"','src="missing-i18n.js"');
 const dom=new JSDOM(html,{url:pathToFileURL(filename).href,runScripts:'dangerously',resources:'usable',virtualConsole:vc,beforeParse(w){
  dispose=w.close.bind(w);
  w.GetParentResourceName=()=> 'crimson_doj';w.Audio=class{pause(){}play(){return Promise.resolve();}};
  w.HTMLMediaElement.prototype.pause=function(){};w.HTMLMediaElement.prototype.load=function(){};
  w.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','');};w.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open');};
  w.fetch=async(url,options)=>{assert.equal(options.method,'POST');const data=JSON.parse(options.body);calls.push({url,data});return {ok:true,json:async()=>url.endsWith('/ui_state')?{ok:true,frame:{action:'open',openToken:42,locale:'fr',data:state}}:{ok:true,data:state}};};
 }});
 try{
  for(let i=0;i<100&&!calls.some(c=>c.url.endsWith(missing?'/uiFailed':'/uiReady'));i++)await sleep(25);
  if(missing){assert.ok(calls.some(c=>c.url.endsWith('/uiFailed')&&c.data.token===42),'missing script reports current session without app dependencies');}
  else{assert.equal(dom.window.document.querySelector('#tablet').hidden,false,'lost native open recovered by state handshake');assert.equal(dom.window.document.querySelector('#heading').textContent,'Tableau de bord');assert.equal(dom.window.document.querySelector('#name').textContent,'Dashboard','identity text preserved');assert.ok(calls.some(c=>c.url.endsWith('/uiReady')&&c.data.token===42));assert.deepEqual(errors,[],'no browser startup errors in French default');}
 }finally{dispose();}
}
(async()=>{await run(false);await run(true);console.log('PASS full French startup, lost-message recovery and missing-script reporting');})().catch(error=>{console.error(error);process.exit(1);});
