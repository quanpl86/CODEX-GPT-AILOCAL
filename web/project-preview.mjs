import http from 'node:http';
import path from 'node:path';
import {readFile,lstat} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
const mime={'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.css':'text/css','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.webp':'image/webp','.glb':'model/gltf-binary','.gltf':'model/gltf+json','.json':'application/json','.mp3':'audio/mpeg','.wav':'audio/wav','.woff2':'font/woff2'};
export function createPreview({root,id,nonce}){
  return http.createServer(async(req,res)=>{
    const origin=`http://127.0.0.1:${res.socket.localPort}`;
    res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'");
    try{
      if(req.headers.host!==`127.0.0.1:${res.socket.localPort}`||(req.headers.origin&&req.headers.origin!==origin)){res.writeHead(403);return res.end('Origin denied');}
      if(req.method!=='GET'){res.writeHead(405);return res.end();}
      if(req.url==='/_hub_health'){res.writeHead(200,{'Content-Type':'application/json'});return res.end(JSON.stringify({root,id,nonce,pid:process.pid}));}
      let relative=decodeURIComponent(req.url.split('?')[0]);if(relative==='/')relative='/index.html';
      const parts=relative.slice(1).split('/');
      if(parts.some(x=>!x||x.startsWith('.')||x.includes('\\')||x.includes(':')||/^(integrations|credentials|auth|secrets)\./i.test(x))||!(/^\/(index\.html|styles\.css|src\/[^]+|public\/[^]+)$/.test(relative)))throw new Error('Denied path');
      const extension=path.extname(relative).toLowerCase();if(!mime[extension])throw new Error('Unsupported asset');
      let full=root;for(const part of parts){full=path.join(full,part);if((await lstat(full)).isSymbolicLink())throw new Error('Linked file denied');}
      const stat=await lstat(full);if(!stat.isFile()||stat.size>64*1024*1024)throw new Error('Asset missing/too large');
      res.writeHead(200,{'Content-Type':`${mime[extension]}${['.html','.css','.js','.mjs','.json'].includes(extension)?'; charset=utf-8':''}`});res.end(await readFile(full));
    }catch{res.writeHead(404);res.end('Not found');}
  });
}
if(process.argv[1]&&pathToFileURL(path.resolve(process.argv[1])).href===import.meta.url){
  const args=process.argv.slice(2),root=path.resolve(args[0]),id=args[1],nonce=args[2];
  const server=createPreview({root,id,nonce});server.listen(0,'127.0.0.1',()=>console.log(JSON.stringify({port:server.address().port,pid:process.pid,root,id,nonce})));
}
