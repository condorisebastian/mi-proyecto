import {createServer} from 'node:http';
import {readFile, realpath, stat} from 'node:fs/promises';
import {dirname, extname, resolve, sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {normalizeCatalog} from './src/catalog.mjs';
import {createClient} from '@supabase/supabase-js';

const root = dirname(fileURLToPath(import.meta.url));
const types = new Map(Object.entries({
  '.html':'text/html; charset=utf-8', '.css':'text/css; charset=utf-8',
  '.js':'text/javascript; charset=utf-8', '.mjs':'text/javascript; charset=utf-8',
  '.json':'application/json; charset=utf-8', '.png':'image/png', '.jpg':'image/jpeg',
  '.svg':'image/svg+xml', '.woff2':'font/woff2', '.ttf':'font/ttf', '.txt':'text/plain; charset=utf-8',
}));
const headers = {
  'X-Content-Type-Options':'nosniff',
  'Referrer-Policy':'strict-origin-when-cross-origin',
  'Permissions-Policy':'camera=(), microphone=(), geolocation=()',
  'Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'",
};

export function createWebsiteServer({
  config = process.env,
  fetchImpl = globalThis.fetch,
  cacheTtlMs = 60_000,
  publicRoot = resolve(root, 'dist'),
} = {}) {
  let baseUrl;
  try {
    const parsed = new URL(config.SUPABASE_URL || config.NEXT_PUBLIC_SUPABASE_URL);
    if (parsed.protocol === 'https:' && !parsed.username && !parsed.password &&
        parsed.pathname === '/' && !parsed.search && !parsed.hash) baseUrl = parsed.origin;
  } catch { /* La configuración privada nunca se reproduce en los errores. */ }
  const key = (config.SUPABASE_PUBLISHABLE_KEY || config.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY)?.trim();
  const configured = Boolean(baseUrl && key?.startsWith('sb_publishable_'));
  const supabase = configured ? createClient(baseUrl, key, {
    auth:{persistSession:false, autoRefreshToken:false, detectSessionInUrl:false},
    global:{fetch:(input, init) => fetchImpl(input, {...init, redirect:'error'})},
  }) : undefined;
  let cached;
  let pending;

  async function loadCatalog() {
    if (cached && cached.expires > Date.now()) return cached;
    if (pending) return pending;
    pending = (async () => {
      if (configured) {
        try {
          const {data, error} = await supabase.rpc('web_route_catalog', {}, {get:true})
            .abortSignal(AbortSignal.timeout(5000));
          if (error) throw new Error('Catalog unavailable');
          const catalog = normalizeCatalog(data);
          return {catalog, source:'supabase', expires:Date.now() + cacheTtlMs};
        } catch { /* Un fallo remoto no publica secretos, URL ni respuesta del proveedor. */ }
      }
      const catalog = normalizeCatalog(JSON.parse(await readFile(resolve(publicRoot, 'routes.json'), 'utf8')));
      return {catalog, source:'reference', expires:Date.now() + Math.min(cacheTtlMs, 10_000)};
    })();
    try { cached = await pending; return cached; }
    finally { pending = undefined; }
  }

  const server = createServer(async (request, response) => {
    const send = (status, body, extra = {}) => {
      response.writeHead(status, {...headers, 'Cache-Control':'no-store', ...extra});
      response.end(request.method === 'HEAD' ? undefined : body);
    };
    try {
      const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
      if (!['GET','HEAD'].includes(request.method)) {
        send(405, 'Método no permitido', {Allow:'GET, HEAD'}); return;
      }
      if (pathname === '/api/routes' || pathname === '/api/health') {
        const result = await loadCatalog();
        const data = pathname === '/api/routes' ? result.catalog : {
          ok:true, database:result.source === 'supabase' ? 'connected' : configured ? 'unavailable' : 'not_configured',
        };
        send(200, JSON.stringify(data), {
          'Content-Type':'application/json; charset=utf-8', 'X-Catalog-Source':result.source,
        });
        return;
      }
      if (pathname.split('/').some(part => part.startsWith('.') || part.includes('\\'))) {
        send(404, 'No encontrado'); return;
      }
      const relative = pathname === '/' ? 'index.html' : pathname.slice(1);
      const candidate = resolve(publicRoot, relative);
      const extension = extname(candidate);
      if (!candidate.startsWith(resolve(publicRoot) + sep) || !types.has(extension)) {
        send(404, 'No encontrado'); return;
      }
      const actual = await realpath(candidate);
      if (!actual.startsWith(await realpath(publicRoot) + sep) || !(await stat(actual)).isFile()) {
        send(404, 'No encontrado'); return;
      }
      const body = await readFile(actual);
      send(200, body, {'Content-Type':types.get(extension)});
    } catch (error) {
      send(error?.code === 'ENOENT' || error?.code === 'ENOTDIR' ? 404 : 500, 'No se pudo completar la consulta.');
    }
  });
  return server;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { process.loadEnvFile(resolve(root, '../.transita-private/website.supabase.env')); }
  catch (error) { if (error.code !== 'ENOENT') throw new Error('No se pudo leer la configuración privada de la web.'); }
  const port = Number(process.env.PORT || 4173);
  const host = process.env.HOST || '127.0.0.1';
  const server = createWebsiteServer();
  server.listen(port, host, () => console.log(`Mi Pasaje: http://${host}:${port}`));
}
