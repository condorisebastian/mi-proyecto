import {startCarousel} from './carousel.js';
import {groupTotal, money} from './fare_math.mjs';

const el = id => document.getElementById(id);
const text = (tag, value, className) => {
  const node = document.createElement(tag);
  node.textContent = value;
  if (className) node.className = className;
  return node;
};
const fold = value => value.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLocaleLowerCase('es');
const icon = name => {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('class', 'icon');
  svg.setAttribute('aria-hidden', 'true');
  const use = document.createElementNS(svg.namespaceURI, 'use');
  use.setAttribute('href', '#i-' + name);
  svg.append(use);
  return svg;
};

const menu = el('main-navigation');
const toggle = el('menu-toggle');
function closeMenu() {
  menu.classList.remove('is-open');
  toggle.setAttribute('aria-expanded', 'false');
}
toggle.addEventListener('click', () => {
  const open = toggle.getAttribute('aria-expanded') !== 'true';
  toggle.setAttribute('aria-expanded', String(open));
  menu.classList.toggle('is-open', open);
});
menu.addEventListener('click', event => {if (event.target.closest('a')) closeMenu();});
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
    closeMenu();
    toggle.focus();
  }
});
matchMedia('(min-width: 961px)').addEventListener('change', closeMenu);

let catalog;
let visibleCount = 6;
let requestedProvince = '';
function readFilters() {
  const params = new URLSearchParams(location.search);
  el('search').value = (params.get('destino') || '').slice(0, 160);
  requestedProvince = (params.get('provincia') || '').slice(0, 160);
  el('province').value = requestedProvince;
  el('quantity').value = params.get('pasajes') || '1';
  const count = Number(params.get('ver'));
  visibleCount = Number.isInteger(count) && count >= 6 && count <= 500 ? count : 6;
}
function saveFilters() {
  const url = new URL(location.href);
  for (const [key, value] of [['destino', el('search').value.trim()], ['provincia', el('province').value]]) {
    if (value) url.searchParams.set(key, value); else url.searchParams.delete(key);
  }
  if (el('quantity').value !== '1') url.searchParams.set('pasajes', el('quantity').value);
  else url.searchParams.delete('pasajes');
  if (visibleCount > 6) url.searchParams.set('ver', String(visibleCount)); else url.searchParams.delete('ver');
  history.replaceState(null, '', url);
}
function renderRoutes() {
  if (!catalog) return;
  const query = fold(el('search').value.trim());
  const province = el('province').value;
  const quantity = Number(el('quantity').value);
  const valid = Number.isInteger(quantity) && quantity >= 1 && quantity <= 50;
  el('quantity').setCustomValidity(valid ? '' : 'Introduce entre 1 y 50 pasajes.');
  const matches = catalog.routes.filter(route => (!province || route.province === province) &&
    fold(route.destination + ' ' + route.province).includes(query));
  el('routes').replaceChildren();
  for (const route of matches.slice(0, visibleCount)) {
    const active = ['piloto', 'verificada'].includes(route.status) && Number.isSafeInteger(route.fare_cents) && route.fare_cents > 0;
    const card = text('article', '', 'route-card' + (active ? '' : ' pending'));
    const heading = text('div', '', 'route-heading');
    heading.append(icon('pin'), text('h3', route.destination));
    const bottom = text('div', '', 'route-bottom');
    bottom.append(text('span', active ? 'Tarifa confirmada' : 'Por verificar', 'route-tag'),
      text('div', active ? money(route.fare_cents) : 'Tarifa por verificar', 'price'),
      text('span', active ? 'por persona' : 'Importe pendiente de confirmación', 'unit'));
    card.append(heading, text('p', route.province, 'province-name'), bottom);
    if (active) {
      const total = text('div', '', 'total');
      total.append(text('span', valid ? quantity + (quantity === 1 ? ' pasaje' : ' pasajes') : 'Cantidad inválida'),
        text('strong', valid ? money(groupTotal(route.fare_cents, quantity)) : '—'));
      card.append(total);
    }
    el('routes').append(card);
  }
  el('route-empty').hidden = matches.length > 0;
  el('load-more').hidden = matches.length <= visibleCount;
  el('route-status').textContent = matches.length === 0 ? 'No hay coincidencias' :
    matches.length + (matches.length === 1 ? ' destino encontrado' : ' destinos encontrados') +
    (matches.length > visibleCount ? ' · Mostrando ' + visibleCount : '');
  for (const button of document.querySelectorAll('[data-destination]')) {
    button.setAttribute('aria-pressed', String(fold(button.dataset.destination) === query && !province));
  }
}
function changedFilters() {
  visibleCount = 6;
  requestedProvince = el('province').value;
  saveFilters();
  renderRoutes();
}
for (const id of ['search', 'province', 'quantity']) el(id).addEventListener('input', changedFilters);
function clearFilters() {
  el('search').value = '';
  el('province').value = '';
  el('quantity').value = '1';
  changedFilters();
}
for (const id of ['clear-search', 'clear-empty']) el(id).addEventListener('click', clearFilters);
for (const button of document.querySelectorAll('[data-destination]')) {
  button.addEventListener('click', () => {
    el('search').value = button.dataset.destination;
    el('province').value = '';
    changedFilters();
  });
}
el('load-more').addEventListener('click', () => {visibleCount += 6; saveFilters(); renderRoutes();});
window.addEventListener('popstate', () => {readFilters(); renderRoutes();});
readFilters();

async function loadCatalog() {
  let response;
  let reference = false;
  try {
    response = await fetch('api/routes', {cache:'no-store', signal:AbortSignal.timeout(8000)});
    if (!response.ok) throw new Error();
    reference = response.headers.get('X-Catalog-Source') !== 'supabase';
  } catch {
    try {
      response = await fetch('routes.json', {signal:AbortSignal.timeout(8000)});
      if (!response.ok) throw new Error();
      reference = true;
    } catch {
      el('route-status').textContent = 'No se pudo cargar el catálogo. Recarga la página para volver a intentarlo.';
      return;
    }
  }
  try {
    catalog = await response.json();
    if (!Array.isArray(catalog.routes)) throw new Error();
    for (const name of [...new Set(catalog.routes.map(route => route.province))].sort((a, b) => a.localeCompare(b, 'es'))) {
      const option = text('option', name); option.value = name; el('province').append(option);
    }
    el('province').value = requestedProvince;
    el('quantity-label').hidden = !catalog.routes.some(route => ['piloto', 'verificada'].includes(route.status) && Number.isSafeInteger(route.fare_cents));
    el('catalog-notice').textContent = reference ? 'Estás consultando el catálogo de referencia. Las tarifas provinciales siguen pendientes de verificación.' : '';
    renderRoutes();
  } catch {
    el('route-status').textContent = 'No se pudo interpretar el catálogo. Recarga la página para intentarlo de nuevo.';
  }
}
void loadCatalog();

let busy = false;
function demoTotal() {return groupTotal(Number(el('demo-route').value), Number(el('demo-quantity').value));}
function updateDemo() {
  const amount = demoTotal();
  el('demo-total').textContent = amount === null ? 'Revisa la cantidad' : money(amount);
}
for (const id of ['demo-route', 'demo-quantity']) el(id).addEventListener('input', updateDemo);
el('tap').addEventListener('click', async () => {
  if (busy) return;
  const amount = demoTotal(), balance = Number(el('demo-balance').value), cents = Math.round(balance * 100);
  if (amount === null || el('demo-balance').value.trim() === '' || !Number.isFinite(balance) || balance < 0 ||
      balance > 1000000 || Math.abs(balance * 100 - cents) > .00001) {
    el('demo-message').textContent = 'Introduce entre 1 y 50 pasajes y un saldo válido con hasta dos decimales.';
    (amount === null ? el('demo-quantity') : el('demo-balance')).focus();
    return;
  }
  busy = true;
  el('tap').setAttribute('aria-busy', 'true');
  for (const id of ['tap', 'demo-balance', 'demo-route', 'demo-quantity', 'reset']) el(id).disabled = true;
  const display = document.querySelector('.pos-display');
  display.classList.remove('approved', 'declined');
  el('demo-message').textContent = 'Verificando saldo de ejemplo…';
  await new Promise(resolve => setTimeout(resolve, matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : 650));
  if (cents < amount) {
    display.classList.add('declined');
    el('demo-message').textContent = 'Saldo insuficiente. El saldo de ejemplo no cambió.';
  } else {
    display.classList.add('approved');
    el('demo-balance').value = ((cents - amount) / 100).toFixed(2);
    el('demo-message').textContent = 'Pago simulado aprobado. Saldo de ejemplo: ' + money(cents - amount) + '.';
  }
  busy = false;
  el('tap').setAttribute('aria-busy', 'false');
  for (const id of ['tap', 'demo-balance', 'demo-route', 'demo-quantity', 'reset']) el(id).disabled = false;
});
el('reset').addEventListener('click', () => {
  if (busy) return;
  el('demo-balance').value = '25.50'; el('demo-quantity').value = '1'; el('demo-route').value = '350';
  document.querySelector('.pos-display').classList.remove('approved', 'declined');
  el('demo-message').textContent = 'Lista para leer la tarjeta de prueba';
  updateDemo();
});
async function loadPhotos() {
  try {
    const response = await fetch('assets/destinations/credits.json');
    if (!response.ok) throw new Error();
    startCarousel(await response.json(), province => {
      requestedProvince = province;
      el('province').value = province;
      el('search').value = '';
      visibleCount = 6;
      saveFilters();
      renderRoutes();
    });
  } catch {
    el('photo-status').textContent = 'No se pudo cargar el carrusel. Puedes seguir consultando los destinos.';
    for (const id of ['destination-prev', 'destination-next', 'destination-play', 'destination-select']) el(id).disabled = true;
  }
}
void loadPhotos();
function openPrivacy() {
  if (location.hash === '#privacidad') el('privacidad').open = true;
}
window.addEventListener('hashchange', openPrivacy);
openPrivacy();
