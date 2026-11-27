const statuses = new Set(['pendiente', 'piloto', 'verificada']);
function clean(value, maximum = 160) {
  if (typeof value !== 'string' || !value.trim() || value.length > maximum || /[\u0000-\u001f]/u.test(value)) {
    throw new TypeError('Catálogo inválido');
  }
  return value.trim();
}

// La respuesta pública se reconstruye campo por campo; nunca se reenvía JSON arbitrario.
export function normalizeCatalog(input) {
  if (!input || input.currency !== 'BOB' || !Array.isArray(input.routes) || input.routes.length > 500) {
    throw new TypeError('Catálogo inválido');
  }
  const ids = new Set();
  const routes = input.routes.map(route => {
    const id = clean(route.id, 80);
    if (!/^[a-z0-9_]+$/u.test(id) || ids.has(id) || !statuses.has(route.status)) throw new TypeError('Ruta inválida');
    ids.add(id);
    const fare = route.fare_cents;
    if (fare !== null && (!Number.isSafeInteger(fare) || fare <= 0 || fare > 10_000_000)) throw new TypeError('Tarifa inválida');
    if ((fare === null) !== (route.status === 'pendiente')) throw new TypeError('Estado de tarifa inválido');
    return {id, destination:clean(route.destination), province:clean(route.province), fare_cents:fare, status:route.status};
  });
  return {version:clean(input.version, 80), origin:clean(input.origin), currency:'BOB', notice:clean(input.notice, 800), routes};
}
