import {createClient} from '@supabase/supabase-js';
import {randomBytes} from 'node:crypto';

export class PortalError extends Error {
  constructor(message, status=400) { super(message); this.status=status; }
}
const options={auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}};
const domain='operadores.mipasaje.invalid';
export const operatorEmail=username=>`${username}@${domain}`;
export const validUsername=value=>typeof value==='string' && /^[a-z][a-z0-9.]{2,39}$/.test(value);

function databaseError(error) {
  if(error.code==='42501') return new PortalError('La cuenta no está habilitada para esta operación.',403);
  if(error.code==='23505') return new PortalError('El documento, usuario o referencia ya está registrado. Comprueba si la operación anterior se completó.',409);
  if(error.code==='P0001') return new PortalError(String(error.message).slice(0,250));
  if(['23502','23514','22P02','22007','22008','22003'].includes(error.code)) return new PortalError('Revisa los campos obligatorios, las fechas y el formato de los datos.');
  return new PortalError('No se pudo consultar el servicio. Conserva los datos e inténtalo otra vez.',503);
}

export class SupabaseBackend {
  constructor(config) {
    this.url=config.SUPABASE_URL;
    this.key=config.SUPABASE_PUBLISHABLE_KEY;
    if(!this.url?.startsWith('https://') || !this.key?.startsWith('sb_publishable_')) throw new Error('Falta la configuración privada de Supabase.');
    this.admin=config.SUPABASE_SERVER_KEY ? createClient(this.url,config.SUPABASE_SERVER_KEY,options) : null;
  }
  client(token) { return createClient(this.url,this.key,{...options,...(token?{global:{headers:{Authorization:`Bearer ${token}`}}}:{})}); }
  async login(username,password) {
    if(!validUsername(username) || typeof password!=='string' || password.length>200) throw new PortalError('Usuario o clave incorrectos.',401);
    const client=this.client();
    const {data,error}=await client.auth.signInWithPassword({email:operatorEmail(username),password});
    if(error || !data.session) throw new PortalError('Usuario o clave incorrectos.',401);
    const session={access:data.session.access_token,refresh:data.session.refresh_token,expires:data.session.expires_at*1000};
    try { await this.call(session,'session'); } catch { await client.auth.signOut(); throw new PortalError('La cuenta de atención no está habilitada.',403); }
    return session;
  }
  async refresh(session) {
    if(session.expires>Date.now()+60000) return;
    const {data,error}=await this.client().auth.refreshSession({refresh_token:session.refresh});
    if(error || !data.session) throw new PortalError('Tu sesión venció. Vuelve a ingresar.',401);
    session.access=data.session.access_token; session.refresh=data.session.refresh_token; session.expires=data.session.expires_at*1000;
  }
  async call(session,action,data={}) {
    await this.refresh(session);
    const {data:result,error}=await this.client(session.access).rpc('operator_portal',{p_action:action,p_data:data}).abortSignal(AbortSignal.timeout(15000));
    if(error) throw databaseError(error);
    return result;
  }
  async logout(session) {
    const client=this.client();
    await client.auth.setSession({access_token:session.access,refresh_token:session.refresh});
    await client.auth.signOut({scope:'local'});
  }
  async createOperator(session,input) {
    const current=await this.call(session,'session');
    if(current.operator.role!=='supervisor') throw new PortalError('Solo supervisión crea cuentas de operadores.',403);
    if(!validUsername(input.username) || typeof input.display_name!=='string' || input.display_name.trim().length<3 || input.display_name.length>100 || !['operador','supervisor'].includes(input.role)) throw new PortalError('Revisa el usuario, nombre y rol de la nueva cuenta.');
    if(!this.admin) throw new PortalError('La creación de cuentas requiere configurar la clave privada del servidor.',503);
    const password=randomBytes(18).toString('base64url');
    const {data,error}=await this.admin.auth.admin.createUser({email:operatorEmail(input.username),password,email_confirm:true});
    if(error || !data.user) throw new PortalError('No se pudo crear la cuenta. Comprueba que el usuario no esté registrado.',409);
    try {
      const operator=await this.call(session,'operators.create',{...input,auth_id:data.user.id});
      return {operator,password,notice:'Entrega esta clave solo al titular. Se muestra una vez.'};
    } catch(error) {
      // Reversión de la cuenta recién creada si no se pudo asignar su rol.
      await this.admin.auth.admin.deleteUser(data.user.id);
      throw error;
    }
  }
}
