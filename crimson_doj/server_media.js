const path=require('node:path'),crypto=require('node:crypto');
const media=require(path.join(GetResourcePath(GetCurrentResourceName()),'media_core.cjs'));
const root=path.join(GetResourcePath(GetCurrentResourceName()),'recordings');
const streams=new Map();
function cancel(source,ticket){const s=streams.get(source);if(s&&(!ticket||ticket===s.ticket)){clearInterval(s.timer);streams.delete(source);}}
exports('storeCapture',(file,maxBytes,cb)=>{const captureRoot=path.join(GetResourcePath('screencapture'),'tmp');media.storeCapture(root,captureRoot,file,maxBytes).then(r=>cb({ok:true,...r})).catch(e=>{console.error('[crimson media]',e.message);cb({ok:false,error:'Could not preserve capture'});});});
exports('deleteStored',(name,cb)=>media.deleteStored(root,name).then(()=>cb({ok:true})).catch(()=>cb({ok:false,error:'Could not remove clip'})));
exports('cancelStream',(source,ticket)=>cancel(Number(source),ticket));
exports('streamStored',async(source,name,maxBytes,cb)=>{source=Number(source);if(!Number.isInteger(source)||source<1)return cb({ok:false,error:'Invalid viewer'});if(streams.has(source)||streams.size>=4)return cb({ok:false,error:'Video transfer busy'});
 const reservation={ticket:crypto.randomUUID(),timer:null};streams.set(source,reservation);
 try{const bytes=await media.readStored(root,name,maxBytes);if(streams.get(source)!==reservation)return cb({ok:false,error:'Cancelled'});const chunkSize=49152,total=Math.ceil(bytes.length/chunkSize);let index=0;
 emitNet('crimson_doj:videoStart',source,{ticket:reservation.ticket,total,bytes:bytes.length});
 reservation.timer=setInterval(()=>{if(streams.get(source)!==reservation)return;index++;const data=bytes.subarray((index-1)*chunkSize,index*chunkSize).toString('base64');TriggerLatentClientEvent('crimson_doj:videoChunk',source,1000000,{ticket:reservation.ticket,index,total,data});if(index===total)cancel(source,reservation.ticket);},100);
 cb({ok:true,ticket:reservation.ticket});
 }catch(e){cancel(source,reservation.ticket);console.error('[crimson media]',e.message);cb({ok:false,error:'Clip unavailable'});}
});
on('playerDropped',()=>cancel(Number(global.source)));
on('onResourceStop',resource=>{if(resource===GetCurrentResourceName())for(const source of streams.keys())cancel(source);});
