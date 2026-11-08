import {mkdir,lstat,readFile,writeFile,rename,unlink,readdir} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import path from 'node:path';
const validKey=key=>typeof key==='string'&&/^[\da-f-]{36}$/.test(key);
const validRecord=record=>record&&validKey(record.id)&&typeof record.hash==='string'&&/^[\da-f]{64}$/.test(record.hash);
export class RequestJournal {
  constructor(directory){this.base=directory;this.directory=path.join(directory,'requests');this.blocked=new Set();}
  async prepare(){await mkdir(this.directory,{recursive:true});if((await lstat(this.directory)).isSymbolicLink())throw new Error('Linked request journal rejected');}
  file(key){if(!validKey(key))throw new Error('Invalid request key');return path.join(this.directory,key);}
  async find(key){
    if(this.blocked.has(key))throw new Error('Legacy request mapping requires recovery before retry.');
    const directory=this.file(key);let entry;
    try{entry=await lstat(directory);}catch(e){if(e.code==='ENOENT')return null;throw new Error('Request journal not readable');}
    try{
      if(entry.isSymbolicLink()||!entry.isDirectory())throw new Error('Invalid request claim');
      const file=path.join(directory,'record.json'),info=await lstat(file);
      if(info.isSymbolicLink()||info.size>512)throw new Error('Invalid request index');
      const record=JSON.parse(await readFile(file,'utf8'));if(!validRecord(record))throw new Error('Invalid request index');return record;
    }catch{throw new Error('Request journal pending/damaged; recover the existing job before retrying this request.');}
  }
  async publish(key,record){
    if(!validRecord(record))throw new Error('Invalid request index record');
    await this.prepare();const directory=this.file(key);
    // The directory is an exclusive durable claim. An interrupted write remains
    // a claim, never an absent key that could admit duplicate work.
    try{await mkdir(directory);}catch(e){if(e.code!=='EEXIST')throw e;const previous=await this.find(key);if(!previous||previous.hash!==record.hash)throw new Error('Request key reused with different content');return {created:false,record:previous};}
    const temp=path.join(directory,`${randomUUID()}.tmp`);
    try{
      await writeFile(temp,JSON.stringify(record),{flag:'wx'});await rename(temp,path.join(directory,'record.json'));return {created:true,record};
    }finally{try{await unlink(temp);}catch(e){if(e.code!=='ENOENT')throw e;}}
  }
  async migrate(){
    await this.prepare();
    const warnings=[];
    for(const name of await readdir(this.base)){
      if(!/^[\da-f-]{36}\.json$/.test(name))continue;
      let job;
      try{const file=path.join(this.base,name),info=await lstat(file);if(info.isSymbolicLink()||info.size>2097152)continue;job=JSON.parse(await readFile(file,'utf8'));}
      catch{warnings.push(`${name}: legacy request mapping could not be read; original retained`);continue;}
      if(job.id===name.slice(0,-5)&&validKey(job.clientKey)&&validRecord({id:job.id,hash:job.requestHash})){
        try{await this.publish(job.clientKey,{id:job.id,hash:job.requestHash});}
        catch{this.blocked.add(job.clientKey);warnings.push(`${name}: request admission requires recovery; original job retained, key remains blocked`);}
      }
    }
    return warnings;
  }
}
