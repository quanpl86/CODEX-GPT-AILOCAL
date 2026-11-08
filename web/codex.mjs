import {readFile} from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {run,codexText} from './adapters.mjs';

// One integration for chat and review. Never accept command/config flags from a request.
export async function askCodex(prompt,cwd,{schemaPath,signal,modelOverride}={}){
  const executable=process.env.HUB_CODEX_JS;
  if(!executable)throw new Error('Codex CLI chưa được cấu hình. Khởi động HUB bằng Start-HubWeb.ps1.');
  const overrides=['-c','features.apps=false','-c','features.plugins=false','-c','features.remote_plugin=false','-c','features.skill_mcp_dependency_install=false','-c','features.shell_tool=false','-c','approval_policy="never"'];
  const paths=new Set([path.join(process.env.CODEX_HOME||path.join(os.homedir(),'.codex'),'config.toml')]);
  for(let cursor=path.resolve(cwd);;){paths.add(path.join(cursor,'.codex','config.toml'));const parent=path.dirname(cursor);if(parent===cursor)break;cursor=parent;}
  for(const configPath of paths){
    let config='';try{config=await readFile(configPath,'utf8');}catch(e){if(e.code!=='ENOENT')throw e;}
    if(/^\s*(?:mcp_servers\s*=|\[mcp_servers\])/m.test(config))throw new Error('MCP inline config cần review riêng trước khi dùng adapter không có tool.');
    for(const kind of ['mcp_servers','plugins']){
      const re=new RegExp(`^\\[${kind}\\.((?:"[^"\\r\\n]+")|(?:'[^'\\r\\n]+')|(?:[\\w-]+))\\]`,'gm');
      for(const match of config.matchAll(re))overrides.push('-c',`${kind}.${match[1]}.enabled=false`);
    }
  }
  const selectedModel=modelOverride||process.env.HUB_CODEX_MODEL;
  const model=selectedModel?['--model',selectedModel]:[];
  const schema=schemaPath?['--output-schema',schemaPath]:[];
  // The desktop's inherited app-tools pipe injects account MCPs independently of
  // config.toml. Do not delegate that pipe or the desktop chat identity to a CLI.
  const env={...process.env};
  for(const key of ['CODEX_APP_TOOLS_PIPE_PATH','CODEX_INTERNAL_ORIGINATOR_OVERRIDE','CODEX_THREAD_ID','CODEX_SESSION_ID','CODEX_TOOL_CALL_ID','OPENAI_API_KEY'])delete env[key];
  let diagnostics='';
  try{
    const output=await run(process.execPath,[executable,'exec','--json','--ephemeral','--sandbox','read-only',...overrides,...model,...schema,'--skip-git-repo-check','-C',cwd,'-'],{cwd,input:prompt,signal,env,onStderr:text=>{if(diagnostics.length<16384)diagnostics+=text;}});
    if(/MCP server startup failed|mcp startup|server_name=/i.test(diagnostics))throw new Error('CLI vẫn khởi tạo MCP ngoài phạm vi. Dừng review/apply và kiểm tra cấu hình client.');
    return codexText(output);
  }
  catch(e){if(e.output)codexText(e.output);throw e;}
}
