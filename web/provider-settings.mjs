import {readFile,writeFile,rename,lstat} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {run} from './adapters.mjs';
const here=path.dirname(fileURLToPath(import.meta.url));
export class ProviderSettings {
  constructor(directory){this.directory=directory;this.file=path.join(directory,'openai-provider.json');this.value={key:'',model:'',version:'initial'};this.loaded=false;this.writing=false;}
  async load(){
    if(this.loaded)return;
    try{
      if((await lstat(this.file)).isSymbolicLink())throw new Error('Linked provider settings rejected');
      const record=JSON.parse(await readFile(this.file,'utf8'));
      const key=await run('pwsh',['-NoProfile','-NonInteractive','-File',path.join(here,'credentials.ps1'),'-Action','unprotect'],{input:record.encryptedKey});
      this.value={key,model:record.model,version:record.version};
    }catch(e){if(e.code!=='ENOENT')this.error='Không mở được khóa đã lưu bằng tài khoản Windows hiện tại. Cấu hình lại trong HUB.';}
    this.loaded=true;
  }
  async publicState(){await this.load();const key=process.env.OPENAI_API_KEY||this.value.key,model=process.env.HUB_OPENAI_MODEL||this.value.model;return {configured:!!(key&&model),model,version:this.value.version,error:this.error||'',environmentOverride:!!(process.env.OPENAI_API_KEY||process.env.HUB_OPENAI_MODEL)};}
  async credentials(){await this.load();return {key:process.env.OPENAI_API_KEY||this.value.key,model:process.env.HUB_OPENAI_MODEL||this.value.model};}
  async update({key,model,version}){
    await this.load();
    if(this.writing)throw new Error('Đang lưu cấu hình; chờ hoàn tất');
    if(version!==this.value.version)throw new Error('Cấu hình đã đổi; làm mới trước khi lưu');
    if(typeof key!=='string'||key.length<10||key.length>512||/\s/.test(key)||typeof model!=='string'||!/^[\w.:-]{1,100}$/.test(model))throw new Error('Cần API key và model ID hợp lệ');
    if(process.platform!=='win32')throw new Error('Lưu khóa bằng DPAPI chỉ hỗ trợ Windows');
    this.writing=true;
    try{
      const encryptedKey=await run('pwsh',['-NoProfile','-NonInteractive','-File',path.join(here,'credentials.ps1'),'-Action','protect'],{input:key});
      const next={model,version:randomUUID(),encryptedKey};
      const temp=path.join(this.directory,`${randomUUID()}.provider.tmp`);
      await writeFile(temp,JSON.stringify(next),{flag:'wx'});await rename(temp,this.file);
      this.value={key,model,version:next.version};delete this.error;return this.publicState();
    }finally{this.writing=false;}
  }
}
