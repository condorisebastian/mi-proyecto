import {spawnSync} from 'node:child_process';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {randomBytes} from 'node:crypto';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createClient} from '@supabase/supabase-js';
import {operatorEmail} from '../src/backend.mjs';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..'), workspace=resolve(root,'..');
const privateRoot=resolve(workspace,'.transita-private'), website=resolve(workspace,'website');
const cli=resolve(website,'node_modules/supabase/dist/supabase.js');
const parse=output=>{const raw=output.trim();return JSON.parse(raw.slice(raw.indexOf('{'),raw.lastIndexOf('}')+1));};
function runCli(args) {
  const result=spawnSync(process.execPath,[cli,...args],{cwd:website,encoding:'utf8',timeout:90000,maxBuffer:4*1024*1024});
  if(result.status!==0) throw new Error('La CLI no pudo preparar la demo. Comprueba la sesión y el acceso al proyecto; no se muestran credenciales.');
  return parse(result.stdout);
}
const quote=value=>"'"+String(value).replaceAll("'","''")+"'";
async function main() {
  await mkdir(privateRoot,{recursive:true,mode:0o700});
  process.loadEnvFile(resolve(privateRoot,'website.supabase.env'));
  const url=process.env.SUPABASE_URL, publishable=process.env.SUPABASE_PUBLISHABLE_KEY;
  const project=new URL(url).hostname.split('.')[0];
  const linked=(await readFile(resolve(website,'supabase/.temp/project-ref'),'utf8')).trim();
  if(project!==linked || !publishable?.startsWith('sb_publishable_')) throw new Error('La configuración y el proyecto enlazado no coinciden.');
  const keys=runCli(['projects','api-keys',`--remote=${project}`,'--reveal','--output-format','json']).keys;
  const serverKey=(keys.find(key=>key.type==='secret')||keys.find(key=>key.name==='service_role'))?.api_key;
  if(!serverKey || serverKey.includes('•')) throw new Error('No se pudo preparar la clave privada del servidor.');
  await writeFile(resolve(privateRoot,'operator-portal.env'),[
    `SUPABASE_URL=${url}`,`SUPABASE_PUBLISHABLE_KEY=${publishable}`,`SUPABASE_SERVER_KEY=${serverKey}`,
    'OPERATOR_PORT=4174','OPERATOR_HOST=127.0.0.1','OPERATOR_SECURE_COOKIE=false',''
  ].join('\n'),{mode:0o600});
  const admin=createClient(url,serverKey,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
  const {data:listed,error:listError}=await admin.auth.admin.listUsers({page:1,perPage:1000});
  if(listError) throw new Error('No se pudieron preparar las cuentas de atención.');
  const templates=[
    {username:'supervisor.demo',display_name:'Supervisión Demo',role:'supervisor'},
    {username:'ana.atencion',display_name:'Ana Demo',role:'operador'},
    {username:'luis.atencion',display_name:'Luis Demo',role:'operador'},
  ];
  let previous=[];
  try {previous=JSON.parse(await readFile(resolve(privateRoot,'operator-demo-accounts.json'),'utf8')).accounts;} catch{}
  const accounts=previous.filter(account=>!templates.some(template=>template.username===account.username)), rows=[];
  for(const template of templates) {
    let user=listed.users.find(item=>item.email===operatorEmail(template.username));
    let password=previous.find(item=>item.username===template.username)?.password;
    if(!user) {
      password=randomBytes(18).toString('base64url');
      const {data,error}=await admin.auth.admin.createUser({email:operatorEmail(template.username),password,email_confirm:true});
      if(error || !data.user) throw new Error('No se pudo crear una cuenta ficticia. Las claves no se muestran.');
      user=data.user;
    }
    accounts.push({...template,...(password?{password}:{notice:'Cuenta existente: se conserva su clave.'})});
    rows.push(`(${quote(user.id)}::uuid,${quote(template.username)},${quote(template.display_name)},${quote(template.role)})`);
  }
  const sql=`begin;\ninsert into operator_private.operators(auth_id,username,display_name,role) values\n${rows.join(',\n')}\non conflict do nothing;\ncommit;\n`;
  const queryFile=resolve(privateRoot,'operator-bootstrap.sql');
  await writeFile(queryFile,sql,{mode:0o600});
  runCli(['db','query',`--remote=${project}`,'--file',queryFile,'--yes','--output-format','json']);
  runCli(['db','query',`--remote=${project}`,'--file',resolve(root,'database/demo_seed.sql'),'--yes','--output-format','json']);
  await writeFile(resolve(privateRoot,'operator-demo-accounts.json'),JSON.stringify({url:'http://127.0.0.1:4174',notice:'Solo demostración. Claves privadas; no compartir ni subir a Git.',accounts},null,2)+'\n',{mode:0o600});
  console.log('Demo preparada: 3 cuentas de atención, 6 clientes ficticios y un padrón académico de prueba.');
  console.log('Accesos guardados únicamente en .transita-private/operator-demo-accounts.json.');
}
main().catch(()=>{console.error('No se pudo completar la preparación del portal. Revisa la conexión y la sesión de Supabase. No se muestran datos privados.');process.exitCode=1;});
