import {spawn} from 'node:child_process';
export function projectEnvironment(){
  const env={...process.env};
  for(const key of Object.keys(env))if(/TOKEN|SECRET|PASSWORD|API_KEY|CREDENTIAL/i.test(key)||/^AWS_ACCESS_KEY_ID$/.test(key)||/^CODEX_(APP_TOOLS_PIPE_PATH|INTERNAL_ORIGINATOR_OVERRIDE|THREAD_ID|SESSION_ID|TOOL_CALL_ID)$/.test(key))delete env[key];
  return env;
}
export function run(command,args,{cwd,input='',signal,timeout=300000,env=process.env,onStderr,spawnProcess=spawn}={}) {
  return new Promise((resolve,reject)=>{
    const child=spawnProcess(command,args,{cwd,windowsHide:true,shell:false,env});
    child.stdout.setEncoding('utf8');child.stderr.setEncoding('utf8');
    let out='',err='',exceeded=false,timedOut=false,aborted=false,stopping=false,settled=false,cleanupTimer,killer;
    const finish=(error)=>{
      if(settled)return;settled=true;clearTimeout(timer);clearTimeout(cleanupTimer);signal?.removeEventListener('abort',abort);
      if(killer&&killer.exitCode===null)killer.kill();
      if(error)reject(error);else resolve(out);
    };
    const stop=()=>{
      if(stopping||settled)return;stopping=true;
      const fallback=()=>{try{child.kill('SIGKILL');}catch(error){finish(new Error(`Owned adapter cleanup failed: ${error.message}`));}};
      // Bound cleanup itself: taskkill can fail or hang independently of the child.
      cleanupTimer=setTimeout(()=>{fallback();finish(new Error(`Adapter interrupted; process cleanup not confirmed for owned PID ${child.pid}. Inspect this process before retrying.`));},5000);
      if(!child.pid){fallback();return;}
      if(process.platform==='win32'){
        killer=spawnProcess('taskkill.exe',['/PID',String(child.pid),'/T','/F'],{windowsHide:true,stdio:'ignore'});
        killer.on('error',fallback);killer.on('close',code=>{if(code!==0)fallback();});
      }else fallback();
    };
    const abort=()=>{aborted=true;stop();};
    const timer=setTimeout(()=>{timedOut=true;stop();},timeout);
    signal?.addEventListener('abort',abort,{once:true});
    if(signal?.aborted)abort();
    child.stdout.on('data',b=>{out+=b;if(Buffer.byteLength(out)>1048576){exceeded=true;stop();}});
    child.stderr.on('data',b=>{if(err.length<8192)err+=b;onStderr?.(b);});
    child.on('error',finish);
    child.on('close',code=>{if(timedOut)finish(new Error('Adapter timed out; owned child exited after cleanup request.'));else if(aborted)finish(new Error('Adapter aborted; owned child exited after cleanup request.'));else if(exceeded)finish(new Error('Adapter output exceeds 1 MiB'));else if(code!==0){const error=new Error(`Adapter exited (${code}). ${err.slice(-2000)}`);error.output=out;finish(error);}else finish();});
    child.stdin.on('error',()=>{});child.stdin.end(input);
  });
}
export function responseText(response){
  const text=(response.output||[]).flatMap(x=>x.content||[]).filter(x=>x.type==='output_text').map(x=>x.text).join('\n');
  if(response.status==='incomplete')throw new Error('OpenAI response incomplete; reduce scope or adjust token limit.');
  if(!text)throw new Error('Provider returned no text response');return text;
}
export async function openAI(prompt,{key=process.env.OPENAI_API_KEY,model=process.env.HUB_OPENAI_MODEL,fetcher=fetch,signal}={}){
  if(!key||!model)throw new Error('Cần cấu hình OPENAI_API_KEY và HUB_OPENAI_MODEL trên máy chủ.');
  const res=await fetcher('https://api.openai.com/v1/responses',{method:'POST',signal,headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:JSON.stringify({model,input:prompt,max_output_tokens:2048,store:false})});
  if(!res.ok)throw new Error(`OpenAI HTTP ${res.status}; kiểm tra quyền, hạn mức và model trên tài khoản API.`);
  return responseText(await res.json());
}
export function codexText(output){
  const events=output.trim().split('\n').map(l=>JSON.parse(l));
  const unexpected=events.find(e=>e.item?.type&& !['agent_message','reasoning','error'].includes(e.item.type));
  if(unexpected)throw new Error(`Codex used an unexpected tool (${unexpected.item.type}); consultation/review rejected.`);
  const failure=events.find(e=>e.type==='turn.failed')||events.find(e=>e.type==='error');
  if(failure)throw new Error(`Codex turn failed: ${String(failure.error?.message||failure.message||'inspect CLI authentication and quota').slice(0,2000)}`);
  const text=events.filter(e=>e.type==='item.completed'&&e.item?.type==='agent_message').map(e=>e.item.text).join('\n');
  if(!text)throw new Error('Codex returned no final answer');return text;
}
