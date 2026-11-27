import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createWebsiteServer} from '../server.mjs';
import {normalizeCatalog} from '../src/catalog.mjs';

const reference = JSON.parse(await readFile(new URL('../dist/routes.json', import.meta.url), 'utf8'));
const exampleKey = ['sb', 'publishable', 'test_value_only'].join('_');
const config = {SUPABASE_URL:'https://example.supabase.co', SUPABASE_PUBLISHABLE_KEY:exampleKey};
async function serve(t, options = {}) {
  const server = createWebsiteServer({config:{}, ...options});
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => {server.closeAllConnections(); server.close(resolve);}));
  return 'http://127.0.0.1:' + server.address().port;
}

test('el catálogo elimina campos ajenos y rechaza importes y estados incoherentes', () => {
  const source = structuredClone(reference);
  source.internal_value = 'must_remain_private';
  source.routes[0].private_value = 'must_remain_private';
  assert.ok(!JSON.stringify(normalizeCatalog(source)).includes('must_remain_private'));
  for (const fare of [-1, 0, 3.5, Number.MAX_SAFE_INTEGER, 350]) {
    const invalid = structuredClone(reference); invalid.routes[0].fare_cents = fare;
    assert.throws(() => normalizeCatalog(invalid));
  }
  const duplicate = structuredClone(reference); duplicate.routes.push(duplicate.routes[0]);
  assert.throws(() => normalizeCatalog(duplicate));
  assert.deepEqual(normalizeCatalog({...reference, routes:[]}).routes, []);
});

test('sin configuración publica el catálogo de referencia sin afirmar conexión', async t => {
  const base = await serve(t);
  const response = await fetch(base + '/api/routes');
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('x-catalog-source'), 'reference');
  const data = await response.json();
  assert.equal(data.routes.length, 29);
  assert.ok(data.routes.every(route => route.fare_cents === null));
  assert.equal((await (await fetch(base + '/api/health')).json()).database, 'not_configured');
});

test('la consulta usa Supabase en el servidor y no expone la clave en respuestas ni archivos', async t => {
  let calls = 0;
  const base = await serve(t, {config, fetchImpl:async (url, init) => {
    calls++;
    assert.equal(String(url), config.SUPABASE_URL + '/rest/v1/rpc/web_route_catalog');
    assert.equal(new Headers(init.headers).get('apikey'), exampleKey);
    return Response.json({...reference, secret_field:exampleKey});
  }});
  const response = await fetch(base + '/api/routes');
  assert.equal(response.headers.get('x-catalog-source'), 'supabase');
  assert.ok(!(await response.text()).includes(exampleKey));
  assert.equal((await (await fetch(base + '/api/health')).json()).database, 'connected');
  assert.equal(calls, 1, 'el catálogo se comparte durante la caché');
  for (const path of ['/server.mjs', '/.env', '/.transita-private/website.supabase.env', '/%2e%2e/.env', '/node_modules/@supabase/ssr/package.json']) {
    const privateResponse = await fetch(base + path);
    assert.equal(privateResponse.status, 404, path);
    assert.ok(!(await privateResponse.text()).includes(exampleKey));
  }
  const html = await fetch(base + '/');
  assert.equal(html.status, 200);
  assert.ok(!(await html.text()).includes(exampleKey));
  assert.match(html.headers.get('content-security-policy'), /connect-src 'self'/u);
  const write = await fetch(base + '/api/routes', {method:'POST', body:'{}'});
  assert.equal(write.status, 405);
});

test('un error remoto o una respuesta inválida usa referencia y oculta el error del proveedor', async t => {
  for (const reply of [() => new Response(exampleKey, {status:503}), () => Response.json({private_field:exampleKey})]) {
    const base = await serve(t, {config, fetchImpl:async () => reply()});
    const response = await fetch(base + '/api/routes');
    assert.equal(response.headers.get('x-catalog-source'), 'reference');
    assert.ok(!(await response.text()).includes(exampleKey));
    assert.equal((await (await fetch(base + '/api/health')).json()).database, 'unavailable');
  }
});

test('las claves privilegiadas no se usan para consultar el catálogo público', async t => {
  const base = await serve(t, {config:{...config, SUPABASE_PUBLISHABLE_KEY:['sb', 'secret', 'test_only'].join('_')},
    fetchImpl:async () => {throw new Error('No debe consultar con privilegios');}});
  assert.equal((await (await fetch(base + '/api/health')).json()).database, 'not_configured');
});

test('la semilla de Supabase coincide con el catálogo compartido', async () => {
  const seed = await readFile(new URL('../supabase/seed.sql', import.meta.url), 'utf8');
  const blocks = [...seed.matchAll(/\$catalog\$([\s\S]*?)\$catalog\$/gu)];
  assert.equal(blocks.length, 2);
  for (const block of blocks) assert.deepEqual(JSON.parse(block[1]), reference);
});
