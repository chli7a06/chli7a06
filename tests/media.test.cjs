const fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict');
const media=require('../crimson_doj/media_core.cjs');
(async()=>{const temp=await fs.mkdtemp(path.join(os.tmpdir(),'crimson-media-test-')),capture=path.join(temp,'capture'),storage=path.join(temp,'private'),outside=path.join(temp,'outside');await fs.mkdir(capture);await fs.mkdir(outside);const bytes=Buffer.concat([Buffer.from([0x1a,0x45,0xdf,0xa3]),Buffer.alloc(1024)]);let checks=0;
const check=(v,label)=>{assert.ok(v,label);checks++;};
const reject=async(fn,label)=>{await assert.rejects(fn,undefined,label);checks++;};
try{
 await fs.writeFile(path.join(capture,'capture.webm'),bytes);const stored=await media.storeCapture(storage,capture,path.join(capture,'capture.webm'),2048);check(media.validName(stored.filename),'generated clip filename bounded');check(stored.bytes===bytes.length,'stored byte count');check((await media.readStored(storage,stored.filename,2048)).equals(bytes),'stored bytes preserved');await reject(()=>fs.stat(path.join(capture,'capture.webm')),'provider temp source moved');check(((await fs.stat(path.join(storage,stored.filename))).mode&0o777)===0o600,'private file permissions');
 await reject(()=>media.readStored(storage,'../secret.webm'),'path traversal denied');await reject(()=>media.readStored(storage,stored.filename,4),'read size cap');
 await fs.writeFile(path.join(outside,'outside.webm'),bytes);await reject(()=>media.storeCapture(storage,capture,path.join(outside,'outside.webm'),2048),'outside provider path denied');
 await fs.symlink(path.join(outside,'outside.webm'),path.join(capture,'linked.webm'));await reject(()=>media.storeCapture(storage,capture,path.join(capture,'linked.webm'),2048),'capture symlink escape denied');
 await fs.writeFile(path.join(capture,'oversized.webm'),bytes);await reject(()=>media.storeCapture(storage,capture,path.join(capture,'oversized.webm'),4),'capture size cap');
 await fs.writeFile(path.join(capture,'invalid.webm'),Buffer.from('not video'));await reject(()=>media.storeCapture(storage,capture,path.join(capture,'invalid.webm'),2048),'invalid container header denied');
 const linkedName='11111111-1111-1111-1111-111111111111.webm';await fs.symlink(path.join(outside,'outside.webm'),path.join(storage,linkedName));await reject(()=>media.readStored(storage,linkedName),'stored symlink escape denied');
 await media.deleteStored(storage,stored.filename);check(await media.deleteStored(storage,stored.filename),'deletion is safe to repeat after partial database failure');await reject(()=>media.readStored(storage,stored.filename),'deleted video is unavailable');
 console.log(`PASS ${checks} media storage, container, privacy and path checks`);
}finally{await fs.rm(temp,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exit(1);});
