import test from 'node:test';
import assert from 'node:assert/strict';
import {advanceWorkflow,runDelivery,validateReview,reviewPrompt} from './workflow.mjs';
const sha='A'.repeat(64);
function fixture(){
  const calls=[],saved=[];
  const job={id:'fixture',project:'sample',action:'workflow',status:'running',message:'Add score',acceptance:'Score adds correctly',files:['src/score.js'],testFiles:['tests/score.test.mjs'],domain:'web',complexity:'low',risk:'low'};
  const deps={persist:async j=>saved.push(structuredClone(j)),review:async()=>({verdict:'approve',summary:'Reviewed',findings:[],proposalSha256:sha,uiChanged:false}),bridge:async r=>{calls.push(r);if(r.action==='stage')return {sha256:sha,proposal:'known'};if(r.action==='apply')return {tests:'not_run'};if(r.action==='applicationState')return {applied:job.applied===true,receipt:job.receipt};if(r.action==='appliedProposal')return {matched:true};if(r.action==='checks')return {passed:true,checks:[{passed:true}],runtime_verified:false};throw new Error('Unexpected bridge');}};
  return {job,deps,calls,saved};
}
test('review precedes explicit apply; actual checks precede browser gate; duplicate apply denied',async()=>{
  const {job,deps,calls,saved}=fixture();
  await advanceWorkflow(job,'start',deps);assert.equal(job.status,'awaiting_apply');assert.deepEqual(calls.filter(c=>!['appliedProposal','applicationState'].includes(c.action)).map(c=>c.action),['stage']);
  await advanceWorkflow(job,'apply',deps);assert.deepEqual(calls.filter(c=>!['appliedProposal','applicationState'].includes(c.action)).map(c=>c.action),['stage','apply','checks']);assert.equal(job.status,'awaiting_browser');assert.equal(job.applied,true);
  assert.ok(saved.some(j=>j.phase==='testing'&&j.applied));
  await assert.rejects(advanceWorkflow(job,'apply',deps),/đã apply/);
});
test('repair gets precise findings, resets apply marker and escalates after two rounds',async()=>{
  const {job,deps,calls}=fixture();deps.review=async()=>({verdict:'changes_requested',summary:'Wrong score',findings:['Fix score increment'],proposalSha256:sha,uiChanged:false});
  await advanceWorkflow(job,'start',deps);assert.equal(job.status,'changes_requested');
  await assert.rejects(advanceWorkflow(job,'apply',deps),/chưa được duyệt/);
  await advanceWorkflow(job,'repair',deps);assert.ok(calls.at(-1).reviewReport.includes('Fix score increment'));assert.equal(job.round,2);
  await assert.rejects(advanceWorkflow(job,'repair',deps),/hai vòng/);
});
test('wrong review hash, inconsistent verdict and stale source fail closed',async()=>{
  assert.throws(()=>validateReview({verdict:'approve',summary:'ok',findings:[],proposalSha256:'other'},sha),/SHA/);
  assert.throws(()=>validateReview({verdict:'approve',summary:'ok',findings:['bug'],proposalSha256:sha,uiChanged:false},sha),/findings/);
  const {job,deps}=fixture();await advanceWorkflow(job,'start',deps);
  deps.bridge=async()=>{throw new Error('Source changed since proposal');};await assert.rejects(advanceWorkflow(job,'apply',deps),/Source changed/);assert.equal(job.applied,false);
});
test('Codex fallback is explicit, stages output and still requires independent review',async()=>{
  const {job,deps,calls}=fixture();deps.cloudStage=async()=>({sha256:sha,proposal:'cloud-proposal'});
  await assert.rejects(advanceWorkflow(job,'cloud',deps),/bị chặn/);
  job.status='failed';job.round=1;await advanceWorkflow(job,'cloud',deps);
  assert.equal(job.implementer,'codex');assert.equal(job.status,'awaiting_apply');assert.equal(job.proposal.proposal,'cloud-proposal');assert.equal(calls.length,0);
});
test('failed checks request repair and never become verified',async()=>{
  const {job,deps}=fixture();const original=deps.bridge;deps.bridge=async r=>r.action==='checks'?{passed:false,checks:[{name:'test',output:'expected 2 actual 1'}]}:original(r);
  await advanceWorkflow(job,'start',deps);await advanceWorkflow(job,'apply',deps);assert.equal(job.status,'tests_failed');assert.ok(job.repairReport.includes('expected 2 actual 1'));
  assert.throws(()=>reviewPrompt(job,{changes:[{proposed:'x'.repeat(180001)}],sha256:sha}),/quá lớn/);
});
test('operator acceptance needs evidence and unchanged checked hashes; automatic evidence stays separate',async()=>{
  const {job,deps}=fixture();await advanceWorkflow(job,'start',deps);await advanceWorkflow(job,'apply',deps);
  await assert.rejects(advanceWorkflow(job,'accept',deps),/bằng chứng/);
  job.checks.checks=[{passed:true,path:'src/score.js',sha256:sha}];job.pendingEvidence={kind:'not_ui',notes:'Pure score module; no UI changed. Executed positive and negative Node tests; all assertions passed.'};
  const original=deps.bridge;deps.bridge=async r=>r.action==='verifyHashes'?{matched:true}:original(r);
  await advanceWorkflow(job,'accept',deps);assert.equal(job.status,'verified');assert.equal(job.verification.automatic,false);assert.equal(job.verification.source,'operator_report');
  await assert.rejects(advanceWorkflow(job,'apply',deps),/kết thúc/);
});
test('opt-in delivery auto applies only after approval and bounds local repairs',async()=>{
  const {job,deps,calls}=fixture();job.autoApply=true;job.autoRepair=true;
  let reviews=0;deps.review=async()=>++reviews===1?{verdict:'changes_requested',summary:'fix',findings:['Fix edge case'],proposalSha256:sha,uiChanged:false}:{verdict:'approve',summary:'ok',findings:[],proposalSha256:sha,uiChanged:false};
  await runDelivery(job,'start',deps);assert.equal(job.status,'awaiting_browser');assert.equal(job.round,2);assert.deepEqual(calls.filter(c=>!['appliedProposal','applicationState'].includes(c.action)).map(c=>c.action),['stage','stage','apply','checks']);
  const blocked=fixture();blocked.job.autoApply=true;blocked.job.autoRepair=true;blocked.deps.review=async()=>({verdict:'changes_requested',summary:'fix',findings:['Fix'],proposalSha256:sha,uiChanged:false});
  await runDelivery(blocked.job,'start',blocked.deps);assert.equal(blocked.job.status,'changes_requested');assert.equal(blocked.job.round,2);assert.equal(blocked.calls.some(c=>c.action==='apply'),false);
});
test('rechecks cannot bless changed unreviewed source and JavaScript UI cannot waive Chrome',async()=>{
  const {job,deps}=fixture();await advanceWorkflow(job,'start',deps);await advanceWorkflow(job,'apply',deps);
  const original=deps.bridge;let checksRun=false;
  deps.bridge=async r=>{if(r.action==='appliedProposal')throw new Error('Source changed after apply');if(r.action==='checks')checksRun=true;return original(r);};
  await assert.rejects(advanceWorkflow(job,'checks',deps),/changed after apply/);assert.equal(checksRun,false);
  job.status='awaiting_browser';job.review.uiChanged=true;job.pendingEvidence={kind:'not_ui',notes:'A sufficiently long operator note must not bypass required browser verification.'};
  await assert.rejects(advanceWorkflow(job,'accept',deps),/JavaScript/);
});
test('interrupted or failed delivery resumes checks only with verified applied receipt',async()=>{
  const {job,deps,calls}=fixture();await advanceWorkflow(job,'start',deps);await advanceWorkflow(job,'apply',deps);
  const count=calls.filter(c=>c.action==='apply').length;
  job.status='interrupted';job.applied=false;
  await advanceWorkflow(job,'checks',deps);assert.equal(job.status,'awaiting_browser');assert.equal(job.applied,true);
  assert.equal(calls.filter(c=>c.action==='apply').length,count);
  job.status='failed';deps.bridge=async()=>{throw new Error('Missing receipt');};
  await assert.rejects(advanceWorkflow(job,'checks',deps),/Missing receipt/);
});
test('repair preserves and verifies the prior applied proposal before replacing it',async()=>{
  const {job,deps}=fixture();await advanceWorkflow(job,'start',deps);await advanceWorkflow(job,'apply',deps);
  job.status='tests_failed';job.repairReport='Fix failed test';
  const prior=structuredClone(job.proposal),original=deps.bridge;
  deps.bridge=async request=>request.action==='stage'?{proposal:'second',sha256:sha}:original(request);
  await advanceWorkflow(job,'repair',deps);
  assert.deepEqual(job.appliedHistory[0].proposal,prior);assert.equal(job.proposal.proposal,'second');assert.equal(job.receipt,undefined);assert.equal(job.checks,undefined);
  job.applied=true;job.status='tests_failed';job.round=1;
  deps.bridge=async()=>{throw new Error('Applied source changed');};
  await assert.rejects(advanceWorkflow(job,'repair',deps),/Applied source changed/);assert.equal(job.proposal.proposal,'second');
  for(const command of ['repair','cloud']){
    const lost=fixture();await advanceWorkflow(lost.job,'start',lost.deps);await advanceWorkflow(lost.job,'apply',lost.deps);
    lost.job.applied=false;delete lost.job.receipt;lost.job.status='failed';
    const original=lost.deps.bridge;
    lost.deps.bridge=async request=>request.action==='applicationState'?{applied:true,receipt:{proposal_sha256:sha}}:original(request);
    lost.deps.cloudStage=async()=>({proposal:'recovery-cloud',sha256:sha});
    await advanceWorkflow(lost.job,command,lost.deps);
    assert.equal(lost.job.appliedHistory[0].receipt.proposal_sha256,sha);assert.equal(lost.job.appliedHistory[0].proposal.proposal,'known');
  }
});
