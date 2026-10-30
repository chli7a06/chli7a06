const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const MAX_BYTES=512*1024*1024;
const validName=name=>typeof name==='string'&&/^[a-f0-9-]{36}\.webm$/.test(name);
async function resolveStored(root,name){if(!validName(name))throw Error('Invalid clip name');const realRoot=await fs.realpath(root);const full=await fs.realpath(path.join(realRoot,name));if(path.dirname(full)!==realRoot)throw Error('Clip path escapes storage');return full;}
async function storeCapture(root,captureRoot,input,maxBytes=MAX_BYTES){
 if(typeof input!=='string')throw Error('Invalid capture path');
 const allowed=await fs.realpath(captureRoot),file=await fs.realpath(input);
 if(path.dirname(file)!==allowed||path.extname(file)!=='.webm')throw Error('Capture path outside provider temporary directory');
 const stat=await fs.stat(file),limit=Math.min(MAX_BYTES,maxBytes);
 if(!stat.isFile())throw Error('Capture is not a regular file');if(stat.size<4||stat.size>limit){await fs.unlink(file);throw Error('Clip exceeds configured limit or is empty');}
 const fd=await fs.open(file,'r');const header=Buffer.alloc(4);try{await fd.read(header,0,4,0);}finally{await fd.close();}if(!header.equals(Buffer.from([0x1a,0x45,0xdf,0xa3]))){await fs.unlink(file);throw Error('Capture is not an EBML/WebM file');}
 await fs.mkdir(root,{recursive:true,mode:0o700});const realRoot=await fs.realpath(root);
 const filename=crypto.randomUUID()+'.webm',destination=path.join(realRoot,filename);try{await fs.copyFile(file,destination,fs.constants?.COPYFILE_EXCL||1);await fs.chmod(destination,0o600);await fs.unlink(file);}catch(error){await fs.unlink(destination).catch(()=>{});throw error;}
 return{filename,bytes:stat.size};
}
async function readStored(root,name,maxBytes=MAX_BYTES){const file=await resolveStored(root,name),stat=await fs.stat(file);if(!stat.isFile()||stat.size<1||stat.size>Math.min(MAX_BYTES,maxBytes))throw Error('Invalid stored clip size');return fs.readFile(file);}
async function deleteStored(root,name){if(!validName(name))throw Error('Invalid clip name');try{await fs.unlink(await resolveStored(root,name));}catch(e){if(e.code!=='ENOENT')throw e;}return true;}
module.exports={MAX_BYTES,validName,storeCapture,readStored,deleteStored};
