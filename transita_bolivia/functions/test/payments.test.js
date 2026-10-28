import {test} from 'node:test';
import assert from 'node:assert/strict';
import {cmac, validateProof} from '../card_crypto.js';
import {settle} from '../payment_core.js';

// Vectores públicos de NXP AN12196, tablas 1 y 4. No son claves de una tarjeta del proyecto.
const publicVectorKey = Buffer.from(Array(16).fill(0));
const proof = {uid: '04DE5F1EACC040', counter: '3D0000', mac: '94EED9EE65337086'};
const input = {proof, amountCents: 2550, quantity: 3, conductorId: 2, reference: 'receipt-001', routeId: 'el_torno'};
const routes = [{id: 'el_torno', fare_cents: 850, status: 'verificada'}, {id: 'sin_tarifa', fare_cents: null, status: 'pendiente'}];
const state = () => ({terminal: {estado: 'activo', conductorId: 2}, card: {estado: 'activo', userId: 1, lastCounter: 60},
  user: {estado: 'activo', puntos: 30}, driver: {estado: 'activo'}});

test('rechaza una tarifa pendiente aunque conserve un importe anterior', () => {
  assert.throws(() => settle(input, state(), publicVectorKey,
    [{id: 'el_torno', fare_cents: 850, status: 'pendiente'}]), /Tarifa de destino inválida/);
});

test('valida la derivación de clave con el vector público NXP', () => {
  const vector = Buffer.from([0x5a,0xce,0x7e,0x50,0xab,0x65,0xd5,0xd5,0x1f,0xd5,0xbf,0x5a,0x16,0xb8,0x20,0x5b]);
  assert.equal(cmac(vector, Buffer.from('3CC30001008004C767F2066180010000', 'hex')).toString('hex'),
    '3a3e8110e05311f7a3fcf0d969bf2b48');
});
test('autentica un mensaje SDM con el vector público NXP', () => assert.equal(validateProof(proof, publicVectorKey), true));
test('rechaza UID, contador, firma y clave manipulados', () => {
  for (const changed of [{uid: '04DE5F1EACC041'}, {counter: '3E0000'}, {mac: '00EED9EE65337086'}, {uid: 'abc'}]) {
    assert.equal(validateProof({...proof, ...changed}, publicVectorKey), false);
  }
  assert.equal(validateProof(proof, Buffer.alloc(16, 1)), false);
});
test('un grupo paga 25.50 y conserva 4.50 de saldo', () => {
  assert.deepEqual(settle(input, state(), publicVectorKey, routes), {duplicate: false, newBalance: 4.5, counter: 61});
});
test('rechaza saldo insuficiente, cuenta bloqueada y tarjeta bloqueada', () => {
  for (const mutate of [s => {s.user.puntos=25;}, s=>{s.user.estado='bloqueado';}, s=>{s.card.estado='bloqueada';}]) {
    const s=state(); mutate(s); assert.throws(()=>settle(input,s,publicVectorKey,routes));
  }
});
test('rechaza terminal ajena, desactivada o conductor bloqueado', () => {
  for (const mutate of [s=>{s.terminal.conductorId=99;}, s=>{s.terminal.estado='bloqueado';}, s=>{s.driver.estado='bloqueado';}]) {
    const s=state(); mutate(s); assert.throws(()=>settle(input,s,publicVectorKey,routes));
  }
});
test('rechaza lecturas repetidas y contadores viejos', () => {
  for (const lastCounter of [61,62]) assert.throws(()=>settle(input,{...state(),card:{...state().card,lastCounter}},publicVectorKey,routes));
});
test('reintentar la misma referencia devuelve el recibo sin descontar otra vez', () => {
  const existing = {amountCents:2550,cardUid:proof.uid,counter:61,quantity:3,routeId:'el_torno',newBalance:4.5};
  assert.deepEqual(settle(input,{...state(),existing},publicVectorKey,routes),{duplicate:true,newBalance:4.5});
  assert.throws(()=>settle({...input,amountCents:850},{...state(),existing},publicVectorKey,routes));
});
test('rechaza tarifa alterada, ruta sin tarifa y cantidad fuera de rango', () => {
  for (const changed of [{amountCents:2551},{routeId:'sin_tarifa'},{quantity:0},{quantity:51},{amountCents:25.5},{amountCents:0}]) {
    assert.throws(()=>settle({...input,...changed},state(),publicVectorKey,routes));
  }
});
