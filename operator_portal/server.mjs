import {createServer} from 'node:http';
import {readFile,writeFile,mkdir,realpath,stat} from 'node:fs/promises';
import {resolve,dirname,extname,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {randomUUID} from 'node:crypto';
import {SupabaseBackend,PortalError,validUsername} from './src/backend.mjs';
import {token,digest,equal,cookieValue,readJson,readBody,validateFile,pointsCents,demoPdf,MAX_FILE} from './src/security.mjs';

const root=dirname(fileURLToPath(import.meta.url));
const contentTypes={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.ttf':'font/ttf','.txt':'text/plain; charset=utf-8'};
const idPattern=/^[0-9]{1,14}$/;
const uuidPattern=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function createPortalServer({backend,config=process.env,clock=Date.now,uploadsRoot=resolve(root,'../.transita-private/operator-uploads')}={}) {
  backend??=new SupabaseBackend(config);
  const sessions=new Map(), attempts=new Map();
  const cookieName='mi_pasaje_operador';
  const secure=config.OPERATOR_SECURE_COOKIE==='true';
  const publicRoot=resolve(root,'public');
  const sweep=setInterval(()=>{
    const now=clock(); for(const [key,s] of sessions) if(s.deadline<now || s.lastSeen+30*60000<now) sessions.delete(key);
    for(const [key,a] of attempts) if(a.until<now) attempts.delete(key);
  },60000); sweep.unref();
  const server=createServer(async(req,res)=>{
    const nonce=randomUUID();
    res.setHeader('X-Request-Id',nonce);
    res.setHeader('X-Content-Type-Options','nosniff');
    res.setHeader('Referrer-Policy','no-referrer');
    res.setHeader('Cache-Control','no-store');
    res.setHeader('Permissions-Policy','camera=(), microphone=(), geolocation=()');
    res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self'; font-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'");
    const json=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json; charset=utf-8'});res.end(JSON.stringify(data));};
    const setCookie=(value,maxAge)=>res.setHeader('Set-Cookie',`${cookieName}=${value}; Path=/; HttpOnly; SameSite=Strict; Max-Age=${maxAge}${secure?'; Secure':''}`);
    try {
      const base=new URL(`${secure?'https':'http'}://${req.headers.host||'localhost'}`);
      if(!['127.0.0.1','localhost','[::1]'].includes(base.hostname) && !secure) throw new PortalError('El portal de demostración solo está disponible en el equipo local.',403);
      const url=new URL(req.url,base), path=url.pathname;
      if(!['GET','HEAD','POST'].includes(req.method)) throw new PortalError('Método no permitido.',405);
      if(req.method==='POST' && (req.headers.origin!==base.origin || req.headers['sec-fetch-site']==='cross-site')) throw new PortalError('La solicitud no procede del portal.',403);
      if(path==='/api/health' && req.method==='GET') return json(200,{ok:true,mode:'demo'});
      if(path==='/api/login' && req.method==='POST') {
        const input=await readJson(req);
        const username=String(input.username||'').trim().toLowerCase();
        if(!validUsername(username)) throw new PortalError('Usuario o clave incorrectos.',401);
        const ip=req.socket.remoteAddress||'local';
        const keys=[digest('user:'+username),digest('ip:'+ip)];
        if(keys.some(key=>{const a=attempts.get(key);return a && a.until>clock() && a.count>=8;})) throw new PortalError('Demasiados intentos. Espera 15 minutos antes de reintentar.',429);
        let auth;
        try {auth=await backend.login(username,input.password);} catch(error) {
          for(const key of keys) {const prev=attempts.get(key);attempts.set(key,{count:prev?.until>clock()?prev.count+1:1,until:prev?.until>clock()?prev.until:clock()+15*60000});}
          throw error;
        }
        // El límite por IP no se reinicia al entrar con otra cuenta válida.
        attempts.delete(keys[0]);
        const sessionToken=token(), csrf=token();
        sessions.set(digest(sessionToken),{auth,csrf,deadline:clock()+8*3600000,lastSeen:clock()});
        setCookie(sessionToken,8*3600);
        return json(200,{...(await backend.call(auth,'session')),csrf});
      }
      if(path.startsWith('/api/')) {
        const sessionToken=cookieValue(req.headers.cookie,cookieName);
        const key=sessionToken?digest(sessionToken):''; const session=sessions.get(key);
        if(!session || session.deadline<clock() || session.lastSeen+30*60000<clock()) {sessions.delete(key);setCookie('',0);throw new PortalError('Ingresa con tu cuenta de operador.',401);}
        if(req.method==='POST' && !equal(req.headers['x-csrf-token'],session.csrf)) throw new PortalError('La sesión de esta página cambió. Actualiza el portal.',403);
        session.lastSeen=clock();
        if(path==='/api/session' && req.method==='GET') return json(200,{...(await backend.call(session.auth,'session')),csrf:session.csrf});
        if(path==='/api/logout' && req.method==='POST') {sessions.delete(key);setCookie('',0);await backend.logout(session.auth).catch(()=>{});return json(200,{ok:true});}
        const match=path.match(/^\/api\/clients\/([0-9]+)(?:\/(status|student|review|evidence|demo-documents|topups|cases))?$/);
        if(match && idPattern.test(match[1])) {
          const customerId=Number(match[1]), action=match[2];
          if(!action && req.method==='GET') return json(200,await backend.call(session.auth,'clients.detail',{customer_id:customerId}));
          if(action==='evidence' && req.method==='POST') {
            const kind=url.searchParams.get('kind'); if(!['carnet','matricula'].includes(kind)) throw new PortalError('Tipo de documento inválido.');
            await backend.call(session.auth,'clients.detail',{customer_id:customerId});
            const bytes=await readBody(req,MAX_FILE), mime=req.headers['content-type']?.split(';')[0], extension=validateFile(bytes,mime), objectId=randomUUID();
            await mkdir(uploadsRoot,{recursive:true,mode:0o700});
            await writeFile(resolve(uploadsRoot,objectId+extension),bytes,{flag:'wx',mode:0o600});
            const filename=String(req.headers['x-file-name']||kind+extension).replace(/[^a-zA-Z0-9._ -]/g,'_').slice(0,120);
            return json(201,await backend.call(session.auth,'evidence.add',{customer_id:customerId,object_id:objectId,kind,mime,filename,sha256:digest(bytes),size_bytes:bytes.length}));
          }
          if(action==='demo-documents' && req.method==='POST') {
            const result=await backend.call(session.auth,'demo.documents',{customer_id:customerId});
            if(!result.registry.matched) throw new PortalError('No hay documentos ficticios para estos datos del padrón.');
            await mkdir(uploadsRoot,{recursive:true,mode:0o700});
            for(const kind of ['carnet','matricula']) {
              const bytes=demoPdf(result.customer,kind), objectId=randomUUID();
              await writeFile(resolve(uploadsRoot,objectId+'.pdf'),bytes,{flag:'wx',mode:0o600});
              await backend.call(session.auth,'evidence.add',{customer_id:customerId,object_id:objectId,kind,mime:'application/pdf',filename:kind+'-FICTICIO.pdf',sha256:digest(bytes),size_bytes:bytes.length});
            }
            return json(201,{ok:true});
          }
          if(req.method==='POST' && ['status','student','review','topups','cases'].includes(action)) {
            const input=await readJson(req);
            if(action==='topups') pointsCents(input.amount);
            const actions={status:'clients.status',student:'student.submit',review:'student.review',topups:'topups.create',cases:'cases.create'};
            return json(200,await backend.call(session.auth,actions[action],{...input,customer_id:customerId}));
          }
        }
        const evidence=path.match(/^\/api\/evidence\/([0-9a-f-]+)$/i);
        if(evidence && uuidPattern.test(evidence[1]) && req.method==='GET') {
          const info=await backend.call(session.auth,'evidence.info',{object_id:evidence[1]});
          const extension=info.mime==='application/pdf'?'.pdf':info.mime==='image/png'?'.png':'.jpg';
          const actual=await realpath(resolve(uploadsRoot,info.object_id+extension));
          if(!actual.startsWith(await realpath(uploadsRoot)+sep)) throw new PortalError('Documento no disponible.',404);
          const bytes=await readFile(actual);
          if(digest(bytes)!==info.sha256) throw new PortalError('El documento no supera la comprobación de integridad.',409);
          res.setHeader('Content-Security-Policy',"sandbox; default-src 'none'");
          res.writeHead(200,{'Content-Type':info.mime,'Content-Disposition':`attachment; filename="${info.kind}-ficticio${extension}"`});return res.end(bytes);
        }
        if(path==='/api/clients' && req.method==='GET') return json(200,await backend.call(session.auth,'clients.list',{q:url.searchParams.get('q')||'',filter:url.searchParams.get('filter')||'',offset:Number(url.searchParams.get('offset')||0)}));
        if(path==='/api/clients' && req.method==='POST') return json(201,await backend.call(session.auth,'clients.register',await readJson(req)));
        if(path==='/api/operators' && req.method==='POST') return json(201,await backend.createOperator(session.auth,await readJson(req)));
        if(path==='/api/operators/status' && req.method==='POST') return json(200,await backend.call(session.auth,'operators.status',await readJson(req)));
        const caseUpdate=path.match(/^\/api\/cases\/([0-9]+)$/);
        if(caseUpdate && req.method==='POST') return json(200,await backend.call(session.auth,'cases.update',{...await readJson(req),case_id:Number(caseUpdate[1])}));
        const collections={'/api/topups':'topups.list','/api/cases':'cases.list','/api/audit':'audit.list','/api/operators':'operators.list','/api/registry':'registry.list'};
        if(collections[path] && req.method==='GET') return json(200,await backend.call(session.auth,collections[path]));
        throw new PortalError('Apartado no encontrado.',404);
      }
      if(!['GET','HEAD'].includes(req.method)) throw new PortalError('Método no permitido.',405);
      const relative=path==='/'?'index.html':decodeURIComponent(path.slice(1));
      if(relative.split('/').some(part=>part.startsWith('.')||part.includes('\\'))) throw new PortalError('No encontrado.',404);
      const candidate=resolve(publicRoot,relative);
      if(!candidate.startsWith(publicRoot+sep) || !contentTypes[extname(candidate)]) throw new PortalError('No encontrado.',404);
      const actual=await realpath(candidate);
      if(!actual.startsWith(await realpath(publicRoot)+sep) || !(await stat(actual)).isFile()) throw new PortalError('No encontrado.',404);
      res.writeHead(200,{'Content-Type':contentTypes[extname(actual)]});res.end(req.method==='HEAD'?undefined:await readFile(actual));
    } catch(error) {
      if(res.headersSent) return res.end();
      if(error instanceof PortalError) return json(error.status,{error:error.message});
      if(error.code==='ENOENT') return json(404,{error:'El archivo no está disponible en este equipo.'});
      json(503,{error:'No se pudo completar la operación. Conserva los datos y vuelve a intentarlo.',request_id:nonce});
    }
  });
  server.on('close',()=>clearInterval(sweep));
  return server;
}

if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  try { process.loadEnvFile(resolve(root,'../.transita-private/operator-portal.env')); }
  catch(error) { if(error.code!=='ENOENT') throw new Error('No se pudo leer la configuración privada del portal.'); }
  const host=process.env.OPERATOR_HOST||'127.0.0.1', port=Number(process.env.OPERATOR_PORT||4174);
  if(!['127.0.0.1','localhost','::1'].includes(host) && process.env.OPERATOR_SECURE_COOKIE!=='true') throw new Error('Para exponer el portal se requiere HTTPS y cookies seguras.');
  createPortalServer().listen(port,host,()=>console.log(`Mi Pasaje Atención: http://${host}:${port}`));
}
