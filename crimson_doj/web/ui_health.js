// Independent startup bridge: the page can recover an open event lost during loading.
(()=>{
 console.info('[crimson_doj] browser UI bridge 4.1.3 loaded');
 let token=null,startupError=null,hasRendered=false,presented=null,polling=false,generation=0;
 const send=async(name,payload)=>{
  try{
   const response=await fetch(`https://${GetParentResourceName()}/${name}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
   return response.ok?await response.json():null;
  }catch{return null;}
 };
 const fail=message=>{if(token===null)return;const current=token;token=null;send('uiFailed',{token:current,error:String(message).slice(0,500)});};
 const recover=async()=>{
  if(polling)return;polling=true;
  try{
   const currentGeneration=generation;
   const state=await send('ui_state',{build:'4.1.3',appReady:window.__crimsonAppReady===true}),frame=state?.ok&&state.frame;
   if(currentGeneration!==generation)return;
   if(!frame||!Number.isInteger(frame.openToken)||frame.openToken===presented)return;
   if(!['open','document'].includes(frame.action))return;
   token=frame.openToken;
   if(startupError){fail(startupError);return;}
   if(!window.__crimsonAppReady)return;
   // A frame is server-authorized data retained by this resource's client, not a new grant.
   window.dispatchEvent(new MessageEvent('message',{data:frame}));
  }finally{polling=false;}
 };
 window.addEventListener('error',event=>{
  const source=event.target?.src;
  if(event.target?.tagName==='IMG'||event.target?.tagName==='VIDEO')return;
  const message=event.message||(source?'Could not load '+source:'UI script error');
  if(!hasRendered)startupError=message;
  fail(message);
 },true);
 window.addEventListener('message',event=>{
  if(event.data?.action==='close'){generation++;token=null;presented=null;return;}
  if(!['open','document'].includes(event.data?.action)||!Number.isInteger(event.data.openToken))return;
  generation++;token=event.data.openToken;
  if(startupError)fail(startupError);
 });
 window.addEventListener('crimsonUiReady',event=>{
  if(token===null||event.detail?.token!==token)return;
  const current=token;hasRendered=true;presented=current;token=null;
  send('uiReady',{token:current}).then(result=>{if(!result?.ok&&presented===current)presented=null;});
 });
 window.addEventListener('DOMContentLoaded',recover);
 setInterval(recover,1000);
})();
