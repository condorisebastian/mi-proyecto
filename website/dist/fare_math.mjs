export function groupTotal(fareCents, quantity) {
  if (!Number.isInteger(fareCents) || fareCents <= 0 || !Number.isInteger(quantity) || quantity < 1 || quantity > 50) return null;
  return fareCents * quantity;
}
export const money = cents => `Bs ${(cents / 100).toLocaleString('es-BO', {minimumFractionDigits:2, maximumFractionDigits:2})}`;
