import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Admissions} from './admissions.mjs';
test('concurrent retries wait for durable admission and share failures',async()=>{
  for(const fail of [false,true]){
    const admissions=new Admissions({find:async()=>null});let release,calls=0,ack=false;
    const gate=new Promise(resolve=>{release=resolve;});
    const create=async()=>{calls++;await gate;if(fail)throw new Error('disk failed');return {id:'job',reused:false};};
    const first=admissions.admit('key','hash',create);
    const second=admissions.admit('key','hash',create).then(value=>{ack=true;return value;});
    const results=Promise.allSettled([first,second]);
    await new Promise(resolve=>setImmediate(resolve));assert.equal(calls,1);assert.equal(ack,false);
    release();const settled=await results;
    if(fail){for(const result of settled){assert.equal(result.status,'rejected');assert.match(result.reason.message,/disk failed/);}}
    else {assert.equal(settled[0].value.id,'job');assert.equal(settled[1].value.reused,true);}
  }
});
