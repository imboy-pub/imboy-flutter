const http = require('http');
const counters={redirect307:0,redirect308:0,dest:0,ok:0,slow:0,cookies:0};
http.createServer((req,res)=>{
 const origin=req.headers.origin||'http://localhost';
 res.setHeader('Access-Control-Allow-Origin',origin);
 res.setHeader('Access-Control-Allow-Credentials','true');
 res.setHeader('Access-Control-Allow-Methods','GET,PUT,OPTIONS');
 res.setHeader('Access-Control-Allow-Headers','content-type,x-amz-checksum-sha256');
 if(req.method==='OPTIONS'){res.writeHead(204).end();return;}
 if(req.url==='/reset'){for(const key of Object.keys(counters)) counters[key]=0;res.end('ok');return;}
 if(req.url==='/set'){res.setHeader('Set-Cookie','cs_probe=synthetic; Path=/; SameSite=Lax');res.end('ok');return;}
 if(req.url==='/cookiecheck'){res.end(req.headers.cookie?.includes('cs_probe=synthetic')?'present':'absent');return;}
 if(req.url==='/stats'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(counters));return;}
 if(req.url==='/redirect307'||req.url==='/redirect308'){counters[req.url.slice(1)]++;if(req.headers.cookie)counters.cookies++;req.resume();res.writeHead(Number(req.url.slice(-3)),{Location:'/destination'}).end();return;}
 if(req.url==='/destination'){counters.dest++;req.resume();res.writeHead(200).end();return;}
 if(req.url==='/slow'){counters.slow++;req.resume();setTimeout(()=>{if(!res.destroyed)res.writeHead(200).end()},5000);return;}
 if(req.url==='/ok'){counters.ok++;if(req.headers.cookie)counters.cookies++;req.resume();res.writeHead(200).end();return;}
 res.writeHead(404).end();
}).listen(19972,'127.0.0.1');
