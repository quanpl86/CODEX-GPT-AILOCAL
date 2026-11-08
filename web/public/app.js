import {agentLabels,statusLabels} from './labels.js';
const $=id=>document.getElementById(id);
let state,loading=false,chatKey='',boardSha='',boardEditingProject='',sourceSelection=null,pendingRequest=null,workflowKey='',draftRestored=false;
const verificationDrafts=new Map();
const draftFields=['project','agent','message','allowed-files','acceptance','test-files','domain','complexity','risk'];
const draftFlags=['auto-apply','auto-repair'];
const names=agentLabels;
const statuses={...statusLabels,completed:'Hoàn tất lượt chạy',tests_failed:'Test thất bại · cần sửa'};
function node(tag,text,className){const e=document.createElement(tag);e.textContent=text;if(className)e.className=className;return e;}
function options(id,items){const values=[['','Chọn dự án…'],...items];const select=$(id),old=select.value;if(JSON.stringify([...select.options].map(o=>[o.value,o.textContent]))===JSON.stringify(values))return;select.replaceChildren(...values.map(([value,label])=>{const o=node('option',label);o.value=value;return o;}));select.value=values.some(x=>x[0]===old)?old:'';}
function project(){return state?.projects.find(p=>p.id===$('project').value);}
function renderContext(){
  const p=project();$('rules-text').textContent=p?.rules||p?.error||'Chưa có quy tắc.';
  $('board').textContent=state.projects.find(x=>x.id===$('board-project').value)?.board||'Chưa có kế hoạch.';
  const agent=$('agent').value,adapter=state.adapters[agent];
  $('adapter-hint').textContent=adapter?.configured?`${adapter.detail} · Chat không áp dụng mã.`:`Chưa cấu hình: ${adapter?.detail}`;
  const records=state.history.filter(x=>x.action==='chat'&&x.project===p?.id&&x.agent===agent).reverse();
  const nextKey=JSON.stringify([p?.id,agent,records]);if(chatKey===nextKey)return;chatKey=nextKey;
  const previousScroll=$('messages').scrollTop,atEnd=$('messages').scrollHeight-$('messages').clientHeight-previousScroll<40;
  $('messages').replaceChildren();
  if(!records.length){const empty=node('div','','empty');empty.append(node('strong','Bắt đầu từ một mục tiêu rõ ràng'),node('span','Hỏi về kế hoạch, nhờ review hoặc chuẩn bị nhiệm vụ.'));$('messages').append(empty);}
  for(const r of records){const user=node('div','','message user');user.append(node('small','Bạn'),node('div',r.message));const reply=node('div','','message');reply.append(node('small',`${names[r.agent]} · ${statuses[r.status]||r.status}`),node('div',r.error||r.result||'Đang chờ AI trả lời…'));$('messages').append(user,reply);}
  $('messages').scrollTop=atEnd?$('messages').scrollHeight:previousScroll;
}
function render(){
  const opened=new Set([...document.querySelectorAll('details[open]')].map(d=>d.dataset.id));
  const warnings=[...(state.reportWarnings||[]),...(state.taskWarnings||[]),...(state.requestWarnings||[])];$('report-health').textContent=warnings.length?`Một số report được cách ly khỏi danh sách, bản gốc vẫn giữ để phục hồi: ${warnings.join('; ')}`:'';
  const projects=state.projects.map(p=>[p.id,p.id]);options('project',projects);options('board-project',projects);
  if(!draftRestored){
    try{const draft=JSON.parse(sessionStorage.getItem('hub-draft')||'{}');for(const id of draftFields)if(typeof draft[id]==='string')$(id).value=draft[id];for(const id of draftFlags)if(typeof draft[id]==='boolean')$(id).checked=draft[id];}catch{$('notice').textContent='Draft cũ không đọc được; báo cáo trên server vẫn giữ nguyên.';}
    draftRestored=true;
  }
  document.querySelectorAll('input,select,textarea').forEach(control=>control.disabled=false);
  $('version').textContent=`Toolkit ${state.version} · RAM trống ${state.resources?.freeGiB??'?'} GiB`;
  const provider=state.providerSettings||{};
  $('provider-status').textContent=provider.error||`${provider.configured?'Có cấu hình':'Chưa cấu hình'}${provider.model?` · ${provider.model}`:''}${provider.environmentOverride?' · Biến môi trường server đang được ưu tiên':''}`;
  $('summary').replaceChildren(...[[state.projects.length,'Dự án đã đăng ký'],[Object.values(state.adapters).filter(a=>a.configured).length,'Adapter có cấu hình'],[state.busy?'01':'00',`Đang chạy · ${state.queued||0} chờ`]].map(([n,t])=>{const e=node('div','','stat');e.append(node('strong',n),node('span',t));return e;}));
  $('project-list').replaceChildren(...state.projects.map(p=>{const e=node('div','','row');e.append(node('strong',p.id),node('small',p.error||`${p.kind} · ${p.root}`));return e;}));
  const preview=state.history.find(j=>['previewStart','previewStop'].includes(j.action)&&j.project===$('board-project').value&&j.status==='completed');
  $('preview-link').replaceChildren();if(preview?.action==='previewStart'&&/^http:\/\/127\.0\.0\.1:\d+$/.test(preview.result?.url||'')){const a=node('a','Mở preview trên Chrome ↗');a.href=preview.result.url;a.target='_blank';a.rel='noopener';$('preview-link').append(a);}
  const nextWorkflowKey=JSON.stringify([state.history.filter(r=>r.action==='workflow'),state.busy]);
  if(workflowKey!==nextWorkflowKey){workflowKey=nextWorkflowKey;$('workflow-list').replaceChildren(...state.history.filter(r=>r.action==='workflow').map(workflowCard));}
  $('report-list').replaceChildren(...state.history.map(r=>{const d=document.createElement('details');d.dataset.id=r.id;d.open=opened.has(r.id);d.append(node('summary',`${statuses[r.status]||r.status} · ${r.action} · ${r.project||r.service} · ${new Date(r.created).toLocaleString('vi-VN')}`),node('pre',r.error||JSON.stringify(r.result||{message:r.message},null,2)));return d;}));
  if(!state.history.length)$('report-list').append(node('p','Chưa có lượt chạy.'));
  $('task-list').replaceChildren(...(state.tasks||[]).map(t=>{const d=document.createElement('details');d.dataset.id=t.id;d.open=opened.has(t.id);d.append(node('summary',`${t.project.id} · ${t.goal} · ${t.status}`),node('pre',JSON.stringify(t,null,2)));return d;}));
  if(!state.tasks?.length)$('task-list').append(node('p','Chưa có nhiệm vụ bàn giao.'));
  $('agent-list').replaceChildren(...Object.entries(state.adapters).map(([id,a])=>{const last=state.history.find(r=>r.agent===id&&r.action==='chat');const e=node('div','','panel');e.append(node('h2',names[id]),node('span',last?.status==='completed'?'Lượt chat gần nhất đạt':last?.status==='failed'?'Lượt chat gần nhất lỗi':a.configured?'Có cấu hình · chưa xác nhận live':'Cần cấu hình','badge'),node('p',a.detail));return e;}));
  $('services').replaceChildren(...state.services.map(s=>{const b=node('button',`Mở ${s}`,'secondary');b.type='button';b.disabled=state.busy||s==='godot';if(s==='godot')b.title='Cần binding dự án đã kiểm chứng';b.onclick=()=>submit({action:'service',service:s});return b;}));
  $('models').replaceChildren(...Object.entries(state.profiles).map(([id,p])=>node('p',`${id}: ${p.model}`)));
  document.querySelectorAll('form:not(.runtime-form) button').forEach(b=>b.disabled=false);
  renderContext();
  for(const d of document.querySelectorAll('details[data-id]'))if(opened.has(d.dataset.id))d.open=true;
}
function workflowCard(job){
  const card=node('article','','panel');card.append(node('h3',`${job.project} · ${statuses[job.status]||job.status}`),node('p',job.message));
  const timeline=node('ol','','timeline');for(const step of job.timeline||[])timeline.append(node('li',`${new Date(step.at).toLocaleTimeString('vi-VN')} · ${step.note}`));card.append(timeline);
  if(job.error)card.append(node('p',job.error,'error'));
  if(job.review)card.append(node('p',`Codex: ${job.review.summary}`));
  if(typeof job.review?.uiChanged==='boolean')card.append(node('p',job.review.uiChanged?'QA bắt buộc: Chrome ngoài cho thay đổi UI/browser.':'Codex phân loại: không thay UI; vẫn cần bằng chứng runtime phù hợp.'));
  if(job.status==='awaiting_browser')card.append(node('p','Checks đã qua. Còn kiểm tra runtime/Chrome; chưa đánh dấu sản phẩm đã nghiệm thu.'));
  if(job.verification)card.append(node('p',`Xác nhận nghiệm thu của người vận hành (không phải test tự động): ${job.verification.notes}`));
  if(job.proposal){const details=document.createElement('details');details.dataset.id=`proposal-${job.id}`;details.append(node('summary',`Xem toàn bộ mã đề xuất · SHA ${job.proposal.sha256}`),node('pre',JSON.stringify(job.proposal.changes,null,2)));card.append(details);}
  for(const previous of job.appliedHistory||[]){const details=document.createElement('details');details.dataset.id=`applied-${job.id}-${previous.proposal.sha256}`;details.append(node('summary',`Lượt đã áp dụng trước · SHA ${previous.proposal.sha256}`),node('pre',JSON.stringify(previous,null,2)));card.append(details);}
  if(job.checks){const details=document.createElement('details');details.append(node('summary',`Kết quả checks: ${job.checks.passed?'đạt':'lỗi'}`),node('pre',JSON.stringify(job.checks,null,2)));card.append(details);}
  const actions=node('div','','service-row');
  const choices=[];
  if(job.status==='awaiting_apply')choices.push(['apply','Áp dụng mã Codex đã duyệt & chạy checks']);
  if(['changes_requested','tests_failed','failed','interrupted'].includes(job.status)&&job.round<2)choices.push(['repair','Gửi báo cáo cho Local sửa / thử lại']);
  if(job.proposal&&!job.applied&&job.status!=='running')choices.push(['review','Codex review lại proposal']);
  if(['awaiting_browser','tests_failed','failed','interrupted'].includes(job.status)&&job.proposal&&job.review?.verdict==='approve')choices.push(['checks','Chạy lại checks']);
  if(job.round>=2&&['tests_failed','changes_requested','failed'].includes(job.status))card.append(node('p','Đã đủ hai vòng local. Cần Codex xử lý phần bị chặn; không tự lặp hoặc đổi provider.'));
  if(['failed','changes_requested','tests_failed','interrupted'].includes(job.status)&&!(job.cloudRounds>=2))choices.push(['cloud','Chuyển phần bị chặn cho Codex viết proposal']);
  if(!['running','cancelled','verified'].includes(job.status))choices.push(['cancel','Đóng nhiệm vụ (giữ mã đã apply)']);
  for(const [command,label] of choices){const b=node('button',label,'secondary');b.disabled=state.busy&&!(command==='cancel'&&job.status==='queued');b.onclick=()=>advance(job.id,command);actions.append(b);}card.append(actions);
  if(job.status==='awaiting_browser'){
    const form=document.createElement('form');form.className='runtime-form';
    const kind=document.createElement('select');kind.setAttribute('aria-label','Loại bằng chứng runtime');
    for(const [value,label] of [['chrome','Đã kiểm tra Chrome thực tế'],['not_ui','Không thay UI · đã kiểm tra runtime phù hợp']]){const option=node('option',label);option.value=value;if(value==='not_ui'&&job.review?.uiChanged!==false)option.disabled=true;kind.append(option);}
    const notes=document.createElement('textarea');notes.setAttribute('aria-label','Bằng chứng nghiệm thu');notes.placeholder='URL/build, bước thử, expected/actual, keyboard/responsive và console/network; hoặc lý do scope không có UI và runtime đã thử.';notes.required=true;notes.minLength=40;notes.maxLength=3000;notes.rows=4;
    const previous=verificationDrafts.get(job.id);if(previous){kind.value=previous.kind;notes.value=previous.notes;}
    const remember=()=>verificationDrafts.set(job.id,{kind:kind.value,notes:notes.value});kind.onchange=remember;notes.oninput=remember;
    const button=node('button','Ghi nhận nghiệm thu của người vận hành','secondary');button.type='submit';button.disabled=state.busy;
    form.append(kind,notes,button);form.onsubmit=e=>{e.preventDefault();advance(job.id,'accept',{kind:kind.value,notes:notes.value});};card.append(form);
  }
  return card;
}
async function advance(id,command,evidence){
  try{const r=await fetch(`/api/workflows/${id}`,{method:'POST',headers:{'Content-Type':'application/json','X-Hub-CSRF':state.csrf},body:JSON.stringify({command,evidence})});const result=await r.json();if(!r.ok)throw new Error(result.error);$('notice').textContent='Đã tiếp nhận bước xử lý. Xem timeline nhiệm vụ.';await refresh();}catch(e){$('notice').textContent=e.message;}
}
async function refresh(){if(loading)return;loading=true;try{const r=await fetch('/api/state');if(!r.ok)throw new Error(`Không đọc được HUB: HTTP ${r.status}`);state=await r.json();render();}catch(e){$('notice').textContent=e.message;}finally{loading=false;}}
async function submit(body){
  if('project' in body&&!body.project){$('notice').textContent='Chọn đúng dự án trước khi giao việc.';return;}
  const payload=JSON.stringify(body);
  if(!pendingRequest||pendingRequest.payload!==payload)pendingRequest={payload,key:crypto.randomUUID()};
  try{const r=await fetch('/api/jobs',{method:'POST',headers:{'Content-Type':'application/json','X-Hub-CSRF':state.csrf,'X-Hub-Request':pendingRequest.key},body:payload});const data=await r.json();if(!r.ok)throw new Error(data.error);pendingRequest=null;$('notice').textContent='Đã xếp hàng. HUB xử lý lần lượt; xem Công việc & báo cáo.';await refresh();}catch(e){$('notice').textContent=e.message;}
}
function selection(){return {project:$('project').value,agent:$('agent').value,message:$('message').value};}
async function readProject(file,projectId=$('board-project').value){const params=new URLSearchParams({project:projectId});if(file)params.set('file',file);const response=await fetch(`/api/project?${params}`);const result=await response.json();if(!response.ok)throw new Error(result.error);return result;}
$('load-files').onclick=async()=>{try{const projectId=$('board-project').value;const result=await readProject(undefined,projectId);if(projectId!==$('board-project').value)return;$('source-list').replaceChildren(...result.files.map(file=>{const b=node('button',file.path,'file-button');b.type='button';b.onclick=async()=>{try{const doc=await readProject(file.path,projectId);if(projectId!==$('board-project').value)return;sourceSelection={project:projectId,path:doc.path};$('source-path').textContent=doc.path;$('source-content').textContent=doc.content;$('add-file').disabled=false;}catch(e){$('notice').textContent=e.message;}};return b;}));}catch(e){$('notice').textContent=e.message;}};
$('add-file').onclick=()=>{if(!sourceSelection)return;$('project').value=sourceSelection.project;const files=new Set($('allowed-files').value.split(/\r?\n/).map(x=>x.trim()).filter(Boolean));files.add(sourceSelection.path);$('allowed-files').value=[...files].join('\n');$('notice').textContent=`Đã thêm ${sourceSelection.path} vào phạm vi của ${sourceSelection.project}.`;};
$('edit-board').onclick=async()=>{try{const projectId=$('board-project').value;const doc=await readProject('WORK-BOARD.md',projectId);if(projectId!==$('board-project').value)return;boardEditingProject=projectId;boardSha=doc.sha256;$('board-content').value=doc.content;$('board-form').hidden=false;}catch(e){$('notice').textContent=e.message;}};
$('board-form').onsubmit=e=>{e.preventDefault();submit({action:'board',project:boardEditingProject,content:$('board-content').value,sha256:boardSha});$('board-form').hidden=true;};
$('chat-form').onsubmit=e=>{e.preventDefault();submit({action:'chat',...selection()});};
$('task-form').onsubmit=e=>{e.preventDefault();if(!$('message').reportValidity())return;submit({action:'task',...selection(),mode:$('mode').value,domain:$('domain').value,complexity:$('complexity').value,risk:$('risk').value});};
$('stage-code').onclick=()=>{if(!$('message').reportValidity())return;submit({action:'stage',...selection(),files:$('allowed-files').value.split(/\r?\n/).map(x=>x.trim()).filter(Boolean),domain:$('domain').value,complexity:$('complexity').value,risk:$('risk').value});};
$('workflow-code').onclick=()=>{
  if(!$('message').reportValidity())return;
  if($('mode').value!=='implement'){$('notice').textContent='Luồng này dành cho code. Với asset/media/review, dùng Tạo nhiệm vụ bàn giao để giao đúng vai trò.';return;}
  if($('risk').value!=='low'||$('complexity').value==='high'){$('notice').textContent='Cần phân rã và Codex review riêng cho task khó/rủi ro cao. Hãy tạo nhiệm vụ bàn giao trước.';return;}
  submit({action:'workflow',...selection(),agent:'local',acceptance:$('acceptance').value,files:$('allowed-files').value.split(/\r?\n/).map(x=>x.trim()).filter(Boolean),testFiles:$('test-files').value.split(/\r?\n/).map(x=>x.trim()).filter(Boolean),domain:$('domain').value,complexity:$('complexity').value,risk:$('risk').value,autoApply:$('auto-apply').checked,autoRepair:$('auto-repair').checked});
};
$('project-form').onsubmit=e=>{e.preventDefault();submit({action:'createProject',project:$('new-id').value,kind:$('kind').value,goal:$('goal').value,template:$('project-template').value});};
$('start-preview').onclick=()=>submit({action:'previewStart',project:$('board-project').value});
$('stop-preview').onclick=()=>submit({action:'previewStop',project:$('board-project').value});
$('provider-form').onsubmit=async e=>{
  e.preventDefault();const key=$('provider-key').value;$('provider-key').value='';
  try{const response=await fetch('/api/settings/openai',{method:'POST',headers:{'Content-Type':'application/json','X-Hub-CSRF':state.csrf},body:JSON.stringify({key,model:$('provider-model').value.trim(),version:state.providerSettings.version})});const result=await response.json();if(!response.ok)throw new Error(result.error);$('notice').textContent='Đã lưu khóa mã hóa. Không có API request tính phí nào được gửi ở bước cấu hình.';await refresh();}catch(error){$('notice').textContent=error.message;}
};
for(const id of ['project','agent','board-project'])$(id).onchange=()=>{renderContext();if(id==='board-project'){$('board-form').hidden=true;sourceSelection=null;$('source-list').replaceChildren();$('source-content').textContent='';$('add-file').disabled=true;}saveDraft();};
document.querySelectorAll('[data-view]').forEach(b=>b.onclick=()=>{document.querySelectorAll('.view').forEach(v=>v.hidden=v.id!==b.dataset.view);document.querySelectorAll('[data-view]').forEach(n=>n.classList.toggle('active',n===b));$('heading').textContent=b.textContent.slice(2);});
$('refresh').onclick=refresh;
function saveDraft(){try{sessionStorage.setItem('hub-draft',JSON.stringify({...Object.fromEntries(draftFields.map(id=>[id,$(id).value])),...Object.fromEntries(draftFlags.map(id=>[id,$(id).checked]))}));}catch{$('notice').textContent='Không lưu được draft trong phiên trình duyệt.';}}
document.querySelectorAll('input,select,textarea,form button').forEach(control=>control.disabled=true);
for(const id of [...draftFields,...draftFlags])$(id).addEventListener('input',saveDraft);
await refresh();
setInterval(refresh,5000);
