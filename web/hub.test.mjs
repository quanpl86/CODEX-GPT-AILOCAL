import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import {spawn} from 'node:child_process';
import {EventEmitter} from 'node:events';
import path from 'node:path';
import {unlink,writeFile,readFile,utimes} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {createHubServer,stateDir,bridge,recoverInterruptedJobs} from './server.mjs';
import {openAI,responseText,codexText,run} from './adapters.mjs';
test('PowerShell bridge propagates denied action without interpreting input as shell',async()=>{
  await assert.rejects(bridge({action:'shell',message:'$(whoami)'}),/Unsupported bridge action/);
  assert.equal(await run(process.execPath,['-e',"process.stdin.on('data',b=>process.stdout.write(b))"],{input:'$(do-not-execute); <script>'}),'$(do-not-execute); <script>');
  const unicode='Xin chào bạn, kiểm tra tiếng Việt 🎓';
  assert.equal(await run('pwsh',['-NoProfile','-NonInteractive','-Command',"[Console]::InputEncoding=[Text.UTF8Encoding]::new($false); [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); [Console]::Write([Console]::In.ReadToEnd())"],{input:unicode}),unicode);
});
test('OpenAI adapter uses official endpoint, bounded output, no storage or tools',async()=>{
  let captured;
  const result=await openAI('question',{key:'fake-test-only',model:'test-model',fetcher:async(url,options)=>{captured={url,options};return {ok:true,json:async()=>({output:[{content:[{type:'output_text',text:'answer'}]}]})};}});
  assert.equal(result,'answer');assert.equal(captured.url,'https://api.openai.com/v1/responses');
  const body=JSON.parse(captured.options.body);assert.equal(body.store,false);assert.equal(body.max_output_tokens,2048);assert.equal(body.tools,undefined);
  await assert.rejects(openAI('x',{key:'',model:''}),/cấu hình/);
  assert.throws(()=>responseText({status:'incomplete'}),/incomplete/);
  assert.equal(codexText('{"type":"item.completed","item":{"type":"agent_message","text":"OK"}}'),'OK');
  assert.throws(()=>codexText('{"type":"turn.failed"}'),/failed/);
});
test('Windows failed taskkill falls back to owned child termination and timeout settles',{skip:process.platform!=='win32'},async()=>{
  let fallbackCalls=0,killerCalls=0;
  const spawnProcess=(command,args,options)=>{
    if(command==='taskkill.exe'){killerCalls++;const failed=new EventEmitter();failed.exitCode=1;setImmediate(()=>failed.emit('close',1));return failed;}
    const child=spawn(command,args,options),kill=child.kill.bind(child);child.kill=(...args)=>{fallbackCalls++;return kill(...args);};return child;
  };
  await assert.rejects(run(process.execPath,['-e','setInterval(()=>{},1000)'],{timeout:100,spawnProcess}),/timed out/);
  assert.equal(killerCalls,1);assert.equal(fallbackCalls,1);
});
test('restart recovers interrupted jobs older than the visible 100 reports without replay',async t=>{
  const files=[];t.after(async()=>{for(const file of files)await unlink(file);});
  const old=path.join(stateDir,`${randomUUID()}.json`);
  for(let i=0;i<102;i++){
    const file=i===0?old:path.join(stateDir,`${randomUUID()}.json`);files.push(file);
    await writeFile(file,JSON.stringify({id:path.basename(file,'.json'),created:new Date().toISOString(),action:'service',status:i===0?'running':'completed'}),{flag:'wx'});
  }
  const yesterday=new Date(Date.now()-86400000);await utimes(old,yesterday,yesterday);await recoverInterruptedJobs();
  assert.equal(JSON.parse(await readFile(old,'utf8')).status,'interrupted');
});
test('HTTP rejects cross-origin, host spoof, traversal, missing CSRF and bad payload',async t=>{
  let dispatched=0;
  let firstStarted;const started=new Promise(resolve=>{firstStarted=resolve;});
  const server=createHubServer({snapshot:async()=>({projects:[],tasks:[],profiles:{},services:[]}),dispatch:async()=>{dispatched++;firstStarted();await new Promise(()=>{});}});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));t.after(()=>new Promise(r=>server.close(r)));
  const url=`http://127.0.0.1:${server.address().port}`;
  assert.equal((await fetch(url+'/api/state',{headers:{Origin:'https://evil.test'}})).status,403);
  const hostStatus=await new Promise((resolve,reject)=>{const r=http.get(url+'/api/state',{headers:{Host:'evil.test'}},res=>{res.resume();resolve(res.statusCode);});r.on('error',reject);});
  assert.equal(hostStatus,403);
  assert.equal((await fetch(url+'/.env')).status,404);
  assert.equal((await fetch(url+'/api/jobs',{method:'POST'})).status,403);
  const state=await(await fetch(url+'/api/state')).json();assert.ok(state.csrf);
  const headers={'Content-Type':'application/json','X-Hub-CSRF':state.csrf};
  const terminalId=randomUUID(),terminalFile=path.join(stateDir,`${terminalId}.json`);
  await writeFile(terminalFile,JSON.stringify({id:terminalId,created:new Date().toISOString(),action:'workflow',status:'verified',project:'fixture',message:'fixture',acceptance:'fixture',files:[],testFiles:[]}),{flag:'wx'});t.after(()=>unlink(terminalFile));
  const deniedTransition=await fetch(url+`/api/workflows/${terminalId}`,{method:'POST',headers,body:JSON.stringify({command:'apply'})});
  assert.equal(deniedTransition.status,400);assert.equal(JSON.parse(await readFile(terminalFile,'utf8')).error,undefined);
  const damagedId=randomUUID(),oversizedId=randomUUID();
  const damaged=path.join(stateDir,`${damagedId}.json`),oversized=path.join(stateDir,`${oversizedId}.json`);
  await writeFile(damaged,'{damaged-fixture',{flag:'wx'});await writeFile(oversized,'x'.repeat(2097153),{flag:'wx'});
  t.after(async()=>{await unlink(damaged);await unlink(oversized);});
  const healthy=await fetch(url+'/api/state');assert.equal(healthy.status,200);const isolated=await healthy.json();
  assert.ok(isolated.reportWarnings.length>=2);assert.equal(isolated.history.some(j=>j.id===damagedId||j.id===oversizedId),false);assert.equal(await readFile(damaged,'utf8'),'{damaged-fixture');
  assert.equal((await fetch(url+'/api/jobs',{method:'POST',headers,body:JSON.stringify({action:'shell',command:'whoami'})})).status,400);
  assert.equal((await fetch(url+'/api/jobs',{method:'POST',headers,body:JSON.stringify({action:'chat',project:'../other',agent:'local',message:'x'})})).status,400);
  assert.equal((await fetch(url+'/api/jobs',{method:'POST',headers,body:'x'.repeat(17000)})).status,413);
  const invalid=await fetch(url+'/api/settings/openai',{method:'POST',headers,body:'{"key":"fake-sensitive-marker" BROKEN'});assert.equal(invalid.status,400);assert.equal((await invalid.text()).includes('fake-sensitive-marker'),false);
  const page=await fetch(url);assert.ok(page.headers.get('content-security-policy').includes("frame-ancestors 'none'"));
  assert.ok((await page.text()).includes('HUB AI'));
  assert.equal((await fetch(url+'/api/jobs',{method:'POST',headers,body:JSON.stringify({action:'stage',project:'ai-local',agent:'local',message:'x',files:['../escape'],domain:'web',complexity:'low',risk:'low'})})).status,400);
  const valid={action:'service',service:'ollama'};
  const keyed={...headers,'X-Hub-Request':'12345678-1234-1234-1234-123456789abc'};
  const accepted=await fetch(url+'/api/jobs',{method:'POST',headers:keyed,body:JSON.stringify(valid)});
  const acceptedBody=await accepted.json();assert.equal(accepted.status,202,JSON.stringify(acceptedBody));const {id}=acceptedBody;
  await started;
  t.after(()=>unlink(path.join(stateDir,`${id}.json`)));
  const duplicate=await fetch(url+'/api/jobs',{method:'POST',headers:keyed,body:JSON.stringify(valid)});
  assert.equal(duplicate.status,202);assert.equal((await duplicate.json()).id,id);assert.equal(dispatched,1);
  assert.equal((await fetch(url+'/api/jobs',{method:'POST',headers:keyed,body:JSON.stringify({action:'service',service:'blender'})})).status,400);
});
