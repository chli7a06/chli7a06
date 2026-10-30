// Independent from app/i18n: report startup errors even if those scripts fail.
(()=>{
 let token=null,startupError=null,hasRendered=false;
 const send=(name,payload)=>{
  try{return fetch(`https://${GetParentResourceName()}/${name}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)}).catch(()=>{});}catch{return Promise.resolve();}
 };
 const fail=message=>{if(token===null)return;const current=token;token=null;send('uiFailed',{token:current,error:String(message).slice(0,500)});};
 window.addEventListener('error',event=>{
  const source=event.target?.src;
  if(event.target?.tagName==='IMG'||event.target?.tagName==='VIDEO')return;
  const message=event.message||(source?'Could not load '+source:'UI script error');
  if(!hasRendered)startupError=message;
  fail(message);
 },true);
 window.addEventListener('message',event=>{
  if(event.data?.action==='close'){token=null;return;}
  if(!['open','document'].includes(event.data?.action)||!Number.isInteger(event.data.openToken))return;
  token=event.data.openToken;
  if(startupError)fail(startupError);
 });
 window.addEventListener('crimsonUiReady',event=>{
  if(token===null||event.detail?.token!==token)return;
  hasRendered=true;const current=token;token=null;send('uiReady',{token:current});
 });
})();
