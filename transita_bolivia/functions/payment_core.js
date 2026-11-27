import {counterValue, validateProof} from './card_crypto.js';

export class Declined extends Error {}
export function cents(value) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 ||
      Math.abs(value * 100 - Math.round(value * 100)) > 0.00001) throw new Declined('Saldo inválido');
  return Math.round(value * 100);
}

/** Se ejecuta dentro de una transacción del servidor. No acepta saldo ni dueño del cliente. */
export function settle(input, state, key, routes) {
  const {terminal, card, user, driver, existing} = state;
  if (!terminal || terminal.estado !== 'activo' || terminal.conductorId !== input.conductorId ||
      !driver || driver.estado !== 'activo') throw new Declined('Terminal no autorizada');
  const amount = input.amountCents;
  const quantity = input.quantity;
  if (!Number.isSafeInteger(amount) || amount <= 0 || amount > Math.min(100000, terminal.maxAmountCents ?? 100000) ||
      !Number.isInteger(quantity) || quantity < 1 || quantity > 50 ||
      !/^[a-zA-Z0-9_-]{8,80}$/.test(input.reference ?? '')) throw new Declined('Datos de cobro inválidos');
  if (!validateProof(input.proof, key)) throw new Declined('Tarjeta no válida');
  if (!card || card.estado !== 'activo' || !Number.isInteger(card.userId) || !user || user.estado !== 'activo') {
    throw new Declined('Tarjeta no disponible');
  }
  if (input.routeId) {
    const route = routes.find(r => r.id === input.routeId);
    if (!route || !['piloto', 'verificada'].includes(route.status) ||
        !Number.isInteger(route.fare_cents) || route.fare_cents <= 0 || route.fare_cents * quantity !== amount) {
      throw new Declined('Tarifa de destino inválida');
    }
  }
  const readCounter = counterValue(input.proof);
  if (existing) {
    if (existing.amountCents !== amount || existing.cardUid !== input.proof.uid.toUpperCase() ||
        existing.counter !== readCounter || existing.quantity !== quantity ||
        (existing.routeId ?? null) !== (input.routeId ?? null)) throw new Declined('Referencia ya utilizada');
    return {duplicate: true, newBalance: existing.newBalance};
  }
  if (readCounter <= (card.lastCounter ?? -1)) throw new Declined('Lectura ya utilizada. Retira y acerca la tarjeta.');
  const balance = cents(user.puntos);
  if (balance < amount) throw new Declined('Saldo insuficiente');
  return {duplicate: false, newBalance: (balance - amount) / 100, counter: readCounter};
}
