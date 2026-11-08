import {spawn} from 'node:child_process';
import {readFile,writeFile,lstat,unlink} from 'node:fs/promises';
import {randomBytes} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {run} from './adapters.mjs';
const here=path.dirname(fileURLToPath(import.meta.url));
export class Previews {
  constructor(directory){this.directory=directory;}
  file(id){if(!/^[a-z][a-z0-9-]{0,63}$/.test(id))throw new Error('Invalid preview project');return path.join(this.directory,`preview-${id}.json`);}
  async record(id){const file=this.file(id);try{if((await lstat(file)).isSymbolicLink())throw new Error('Linked preview receipt');return JSON.parse(await readFile(file,'utf8'));}catch(e){if(e.code==='ENOENT')return null;throw e;}}
  async verify(record){
    if(!record||!Number.isInteger(record.port)||record.port<1024||record.port>65535)return false;
    try{const r=await fetch(`http://127.0.0.1:${record.port}/_hub_health`,{signal:AbortSignal.timeout(2000)});const data=await r.json();return r.ok&&data.pid===record.pid&&data.id===record.id&&data.root===record.root&&data.nonce===record.nonce;}catch{return false;}
  }
  async start(context){
    const p=context.project,metadata=JSON.parse(context.metadata||'{}');
    if(metadata.stack!=='vanilla-web')throw new Error('Preview trực tiếp hỗ trợ template vanilla-web. Stack khác cần launcher được đăng ký riêng.');
    const previous=await this.record(p.id);if(previous&&await this.verify(previous)){if(previous.root!==p.root)throw new Error('Preview root khác registry');return {url:`http://127.0.0.1:${previous.port}`,project:p.id,reused:true};}
    const nonce=randomBytes(16).toString('hex');
    const child=spawn(process.execPath,[path.join(here,'project-preview.mjs'),p.root,p.id,nonce],{cwd:p.root,windowsHide:true,stdio:['ignore','pipe','pipe']});
    child.stdout.setEncoding('utf8');child.stderr.resume();
    const record=await new Promise((resolve,reject)=>{
      let out='';const timer=setTimeout(()=>{child.kill();reject(new Error('Preview startup timed out'));},10000);
      child.on('error',e=>{clearTimeout(timer);reject(e);});child.on('exit',()=>{clearTimeout(timer);reject(new Error('Preview exited before readiness'));});
      child.stdout.on('data',text=>{out+=text;if(out.includes('\n')){clearTimeout(timer);try{resolve(JSON.parse(out.split('\n')[0]));}catch{child.kill();reject(new Error('Invalid preview readiness'));}}});
    });
    if(record.pid!==child.pid||record.id!==p.id||record.root!==p.root||record.nonce!==nonce||!await this.verify(record)){child.kill();throw new Error('Preview identity/readiness mismatch');}
    try{await writeFile(this.file(p.id),JSON.stringify(record),{flag:'w'});}catch(e){child.kill();throw e;}child.unref();child.stdout.unref?.();child.stderr.unref?.();
    return {url:`http://127.0.0.1:${record.port}`,project:p.id,reused:false};
  }
  async stop(context){
    const p=context.project,record=await this.record(p.id);
    if(!record)return {stopped:false,reason:'No owned preview'};
    if(record.root!==p.root)throw new Error('Preview root differs from registry');
    await run('pwsh',['-NoProfile','-NonInteractive','-File',path.join(here,'../Stop-HubPreview.ps1'),'-ProcessId',String(record.pid),'-Nonce',record.nonce]);
    await unlink(this.file(p.id));return {stopped:true,project:p.id};
  }
}
