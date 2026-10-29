import {initializeApp} from 'firebase-admin/app';
import {getFirestore, FieldValue} from 'firebase-admin/firestore';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {defineSecret, defineBoolean} from 'firebase-functions/params';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {Declined, settle} from './payment_core.js';

initializeApp();
const db = getFirestore();
const keys = defineSecret('NFC_SDM_KEYS');
const ledgerLocked = defineBoolean('POS_LEDGER_LOCKED', {default: false});
const catalog = JSON.parse(readFileSync(new URL('./province_routes.json', import.meta.url), 'utf8'));

export const authorizeCardPayment = onCall({region: 'southamerica-east1',
  secrets: [keys], enforceAppCheck: true, maxInstances: 2}, async request => {
  if (!request.auth || request.auth.token.firebase?.sign_in_provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'Activa la sesión de la terminal.');
  }
  // No habilitar sobre las reglas de demostración que permiten cambiar saldos desde el cliente.
  if (!ledgerLocked.value()) throw new HttpsError('failed-precondition', 'La terminal todavía no está habilitada para cobros.');
  const input = request.data;
  if (!input?.proof || !/^[0-9a-f]{14}$/i.test(input.proof.uid ?? '') || !Number.isSafeInteger(input.conductorId)) {
    throw new HttpsError('invalid-argument', 'Datos de cobro inválidos.');
  }
  const uid = input.proof.uid.toUpperCase();
  let key;
  try {
    const value = JSON.parse(keys.value())[uid];
    if (typeof value !== 'string' || !/^[0-9a-f]{32}$/i.test(value) || /^0+$/.test(value)) throw new Error();
    key = Buffer.from(value, 'hex');
  } catch (_) { throw new HttpsError('permission-denied', 'Tarjeta no disponible.'); }
  const terminalRef = db.collection('pos_terminals').doc(request.auth.uid);
  const cardRef = db.collection('nfc_cards').doc(uid);
  const driverRef = db.collection('conductores').doc(`c-${input.conductorId}`);
  const receiptId = createHash('sha256').update(`${request.auth.uid}:${input.reference}`).digest('hex');
  const receiptRef = db.collection('pos_receipts').doc(receiptId);
  const paymentRef = db.collection('transacciones').doc(`nfc-${receiptId}`);
  try {
    return await db.runTransaction(async tx => {
      const [terminal, card, driver, receipt] = await tx.getAll(terminalRef, cardRef, driverRef, receiptRef);
      const cardData = card.data();
      if (!Number.isSafeInteger(cardData?.userId) || cardData.userId <= 0) throw new Declined('Tarjeta no disponible');
      const userRef = db.collection('usuarios').doc(`u-${cardData.userId}`);
      const user = await tx.get(userRef);
      const result = settle(input, {terminal: terminal.data(), card: cardData, user: user.data(),
        driver: driver.data(), existing: receipt.data()}, key, catalog.routes);
      if (result.duplicate) return {ok: true, receipt: receiptId, duplicate: true};
      tx.update(userRef, {puntos: result.newBalance});
      tx.update(cardRef, {lastCounter: result.counter});
      tx.create(receiptRef, {amountCents: input.amountCents, cardUid: uid, counter: result.counter,
        quantity: input.quantity, routeId: input.routeId ?? null, newBalance: result.newBalance,
        terminalUid: request.auth.uid, fecha: FieldValue.serverTimestamp()});
      tx.create(paymentRef, {id: Date.now(), id_usuario: cardData.userId, id_conductor: input.conductorId,
        puntos: input.amountCents / 100, tipo: 'cobro_viaje', metodo_pago: 'nfc', estado: 'exitoso',
        fecha: FieldValue.serverTimestamp(), cantidad_pasajeros: input.quantity, tipo_usuario: user.data().tipo,
        nombre_pasajero: user.data().nombre ?? '', apellido_pasajero: user.data().apellido ?? '',
        modalidad_cobro: input.routeId ? 'provincia' : 'personalizado', ruta_id: input.routeId ?? null});
      return {ok: true, receipt: receiptId, duplicate: false};
    });
  } catch (error) {
    if (error instanceof Declined) throw new HttpsError('failed-precondition', error.message);
    throw new HttpsError('internal', 'No se pudo confirmar el cobro. Consulta su estado antes de repetirlo.');
  }
});
