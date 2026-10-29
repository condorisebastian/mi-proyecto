import {createCipheriv, timingSafeEqual} from 'node:crypto';

// AES-CMAC (NIST SP800-38B) y SDM de NXP AN12196, §§3.3 y 3.4.4.2.1.
const xor = (a, b) => Buffer.from(a.map((v, i) => v ^ b[i]));
function block(key, data) {
  const cipher = createCipheriv('aes-128-ecb', key, null);
  cipher.setAutoPadding(false);
  return Buffer.concat([cipher.update(data), cipher.final()]);
}
function double(data) {
  const out = Buffer.alloc(16);
  for (let i = 0; i < 16; i++) out[i] = ((data[i] << 1) | (i < 15 ? data[i + 1] >> 7 : 0)) & 255;
  if (data[0] & 128) out[15] ^= 0x87;
  return out;
}
export function cmac(key, data) {
  if (key.length !== 16) throw new Error('Clave de tarjeta inválida');
  const k1 = double(block(key, Buffer.alloc(16)));
  const k2 = double(k1);
  const count = Math.max(1, Math.ceil(data.length / 16));
  let last = Buffer.alloc(16);
  const tail = data.subarray((count - 1) * 16);
  tail.copy(last);
  if (tail.length === 16) last = xor(last, k1);
  else { last[tail.length] = 128; last = xor(last, k2); }
  let state = Buffer.alloc(16);
  for (let i = 0; i < count - 1; i++) state = block(key, xor(state, data.subarray(i * 16, i * 16 + 16)));
  return block(key, xor(state, last));
}
export function validateProof(proof, key) {
  if (!proof || !/^[0-9a-f]{14}$/i.test(proof.uid) ||
      !/^[0-9a-f]{6}$/i.test(proof.counter) || !/^[0-9a-f]{16}$/i.test(proof.mac)) return false;
  const sv = Buffer.from(`3cc300010080${proof.uid}${proof.counter}`, 'hex');
  const session = cmac(key, sv);
  const full = cmac(session, Buffer.alloc(0));
  const expected = Buffer.from(Array.from({length: 8}, (_, i) => full[i * 2 + 1]));
  return timingSafeEqual(expected, Buffer.from(proof.mac, 'hex'));
}
export function counterValue(proof) {
  return Buffer.from(proof.counter, 'hex').readUIntLE(0, 3);
}
