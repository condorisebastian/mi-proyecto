import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {once} from 'node:events';
import {createPortalServer} from '../server.mjs';
import {PortalError} from '../src/backend.mjs';

async function fixture(t){
  let now=Date.now();const secret=randomUUID(),privateToken=randomUUID();
  const backend={active:true,calls:[],async login(username,password){if(password!==secret)throw new PortalError('Usuario o clave incorrectos.',401);return {access:privateToken,refresh:randomUUID()};},
    async call(_,action,data){this.calls.push({action,data});if(!this.active)throw new PortalError('Cuenta no habilitada.',403);if(action==='session')return {operator:{username:'ana.demo',role:'operador',display_name:'Ana Demo'},summary:{}};if(action==='clients.detail')return {customer:{}};return {items:[],total:0};},async logout(){}};
  const uploads=await mkdtemp(join(tmpdir(),'mi-pasaje-http-'));
  const server=createPortalServer({backend,config:{},clock:()=>now,uploadsRoot:uploads});
  server.listen(0,'127.0.0.1');await once(server,'listening');
  t.after(async()=>{server.closeAllConnections();server.close();await rm(uploads,{recursive:true,force:true});});
  const origin=`http://127.0.0.1:${server.address().port}`;
  const request=(path,init={})=>fetch(origin+path,{...init,headers:{Origin:origin,...(init.body?{'Content-Type':'application/json'}:{}),...init.headers}});
  async function login(){const response=await request('/api/login',{method:'POST',body:JSON.stringify({username:'ana.demo',password:secret})});assert.equal(response.status,200);return {cookie:response.headers.get('set-cookie').split(';')[0],data:await response.json(),rawCookie:response.headers.get('set-cookie')};}
  return {backend,request,login,origin,privateToken,advance:ms=>now+=ms};
}
test('sin sesión no se consultan clientes; HTML y assets no entregan configuración privada',async t=>{
  const f=await fixture(t);assert.equal((await f.request('/api/clients')).status,401);
  for(const path of ['/server.mjs','/.env','/src/backend.mjs','/%2e%2e/.transita-private/operator-portal.env'])assert.equal((await f.request(path)).status,404);
  const html=await f.request('/');assert.equal(html.status,200);assert.match(await html.text(),/Mi Pasaje/);
  assert.match(html.headers.get('content-security-policy'),/frame-ancestors 'none'/);assert.equal(html.headers.get('access-control-allow-origin'),null);
});
test('la sesión es opaca y HttpOnly; ni JWT ni refresh token llegan al navegador',async t=>{
  const f=await fixture(t),login=await f.login();
  assert.match(login.rawCookie,/HttpOnly/);assert.match(login.rawCookie,/SameSite=Strict/);
  assert.equal(JSON.stringify(login.data).includes(f.privateToken),false);assert.equal(login.data.csrf.length,64);
  const response=await f.request('/api/session',{headers:{Cookie:login.cookie}});assert.equal(response.status,200);
});
test('las escrituras requieren origen propio y CSRF antes de llegar a la base de datos',async t=>{
  const f=await fixture(t),login=await f.login();f.backend.calls=[];
  let response=await f.request('/api/clients/100001/status',{method:'POST',headers:{Cookie:login.cookie},body:'{}'});assert.equal(response.status,403);assert.equal(f.backend.calls.length,0);
  response=await f.request('/api/clients/100001/status',{method:'POST',headers:{Cookie:login.cookie,Origin:'https://otro.example','X-CSRF-Token':login.data.csrf},body:'{}'});assert.equal(response.status,403);assert.equal(f.backend.calls.length,0);
  response=await f.request('/api/clients/100001/status',{method:'POST',headers:{Cookie:login.cookie,'X-CSRF-Token':login.data.csrf},body:JSON.stringify({status:'bloqueado',reason:'Prueba de restricción.'})});assert.equal(response.status,200);assert.equal(f.backend.calls.at(-1).action,'clients.status');
});
test('cerrar sesión invalida la cookie y el servidor expira sesiones inactivas',async t=>{
  const f=await fixture(t),login=await f.login();
  const response=await f.request('/api/logout',{method:'POST',headers:{Cookie:login.cookie,'X-CSRF-Token':login.data.csrf},body:'{}'});
  assert.equal(response.status,200);assert.match(response.headers.get('set-cookie'),/Max-Age=0/);assert.equal((await f.request('/api/session',{headers:{Cookie:login.cookie}})).status,401);
  const again=await f.login();f.advance(31*60000);assert.equal((await f.request('/api/session',{headers:{Cookie:again.cookie}})).status,401);
});
test('un operador desactivado pierde acceso con la misma sesión',async t=>{
  const f=await fixture(t),login=await f.login();f.backend.active=false;
  const response=await f.request('/api/clients',{headers:{Cookie:login.cookie}});assert.equal(response.status,403);
});
test('los intentos fallidos se limitan y el contenido HTML nunca se acepta como documento',async t=>{
  const f=await fixture(t),login=await f.login();
  const upload=await f.request('/api/clients/100001/evidence?kind=carnet',{method:'POST',headers:{Cookie:login.cookie,'X-CSRF-Token':login.data.csrf,'Content-Type':'image/png'},body:'<script>invalid document</script>'});
  assert.equal(upload.status,400);assert.equal(f.backend.calls.some(x=>x.action==='evidence.add'),false);
  for(let i=0;i<8;i++)assert.equal((await f.request('/api/login',{method:'POST',body:JSON.stringify({username:'ana.demo',password:randomUUID()})})).status,401);
  assert.equal((await f.request('/api/login',{method:'POST',body:JSON.stringify({username:'ana.demo',password:randomUUID()})})).status,429);
});
test('un monto manipulado se rechaza en HTTP antes de llamar a la recarga',async t=>{
  const f=await fixture(t),login=await f.login();
  const response=await f.request('/api/clients/100001/topups',{method:'POST',headers:{Cookie:login.cookie,'X-CSRF-Token':login.data.csrf},body:JSON.stringify({amount:'1.005'})});
  assert.equal(response.status,400);assert.equal(f.backend.calls.some(x=>x.action==='topups.create'),false);
});
