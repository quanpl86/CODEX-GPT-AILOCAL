import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,readFile,readdir,unlink,rmdir} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {ProviderSettings} from './provider-settings.mjs';
test('DPAPI settings do not persist or return plaintext key; stale update rejected',{skip:process.platform!=='win32'},async t=>{
  const dir=await mkdtemp(path.join(os.tmpdir(),'hub-provider-'));
  t.after(async()=>{for(const name of await readdir(dir))await unlink(path.join(dir,name));await rmdir(dir);});
  const key='fake-test-key-not-a-real-credential';
  const settings=new ProviderSettings(dir);const initial=await settings.publicState();
  const result=await settings.update({key,model:'test-model',version:initial.version});
  assert.equal(JSON.stringify(result).includes(key),false);
  assert.equal((await readFile(path.join(dir,'openai-provider.json'),'utf8')).includes(key),false);
  const reloaded=new ProviderSettings(dir);await reloaded.load();assert.equal(reloaded.value.key,key);assert.equal(reloaded.value.model,'test-model');
  await assert.rejects(settings.update({key,model:'other',version:'stale'}),/đã đổi/);
});
