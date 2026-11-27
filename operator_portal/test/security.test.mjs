import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {pointsCents,validateFile,demoPdf,equal,token,digest} from '../src/security.mjs';
import {SupabaseBackend,PortalError} from '../src/backend.mjs';

test('los puntos conservan 0.50 y rechazan redondeos, valores negativos y excesos',()=>{
  assert.equal(pointsCents('0.50'),50);assert.equal(pointsCents('10.5'),1050);assert.equal(pointsCents('1000.00'),100000);
  for(const value of ['0','-1','0.51','1.005','1000.50','1e2','Infinity','NaN',' 1.00',1])assert.throws(()=>pointsCents(value),PortalError);
});
test('CSRF compara bytes sin fallar con Unicode y los tokens no se guardan en claro',()=>{
  const first=token(),second=token();assert.notEqual(first,second);assert.equal(equal(first,first),true);assert.equal(equal(first,second),false);
  assert.equal(equal('é','a'),false);assert.equal(equal(null,first),false);assert.notEqual(digest(first),first);
});
test('los documentos exigen contenido compatible y los PDF de prueba se identifican como ficticios',()=>{
  const bytes=demoPdf({first_name:'Lucía',last_name:'Rojas',identity_document:'DEMO-1000001',institution:'Instituto Demo',student_id:'DEMO',enrollment_id:'DEMO',student_card:'DEMO'},'carnet');
  assert.equal(validateFile(bytes,'application/pdf'),'.pdf');assert.match(bytes.toString(),/FICTICIO/);assert.match(bytes.toString(),/Sin validez/);
  assert.throws(()=>validateFile(Buffer.from('<script>alert(1)</script>'),'image/png'),PortalError);
  assert.throws(()=>validateFile(Buffer.alloc(6*1024*1024),'application/pdf'),PortalError);
});
test('un operador no llega a crear usuarios de Auth aunque invoque el endpoint manualmente',async()=>{
  const backend=Object.create(SupabaseBackend.prototype);let reachedAdmin=false;
  backend.call=async()=>({operator:{role:'operador'}});
  backend.admin={auth:{admin:{createUser:async()=>{reachedAdmin=true;}}}};
  await assert.rejects(()=>backend.createOperator({},{username:'persona.demo',display_name:'Persona Demo',role:'supervisor'}),error=>error.status===403);
  assert.equal(reachedAdmin,false);
});
test('crear una cuenta revierte el usuario recién creado si falla la asignación del rol',async()=>{
  const backend=Object.create(SupabaseBackend.prototype);const id=randomUUID();let reverted=false;
  backend.call=async(_,action)=>{if(action==='session')return {operator:{role:'supervisor'}};throw new PortalError('Cuenta no habilitada.',403);};
  backend.admin={auth:{admin:{createUser:async()=>({data:{user:{id}}}),deleteUser:async userId=>{reverted=userId===id;}}}};
  await assert.rejects(()=>backend.createOperator({},{username:'persona.demo',display_name:'Persona Demo',role:'operador'}));assert.equal(reverted,true);
});
