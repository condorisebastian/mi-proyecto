# Web de Mi Pasaje

La portada utiliza la marca de la app, las fotografías locales de Santa Cruz y
el carrusel automático de tres segundos con fundido de 650 ms. El visitante
puede buscar destinos, filtrar provincias, compartir el filtro mediante la URL,
mostrar más resultados y probar pagos con saldo ficticio. El menú se adapta al
móvil y respeta teclado y movimiento reducido.

## Ejecutar

Requiere Node.js 22 o posterior. Desde `website/`:

```powershell
npm ci
npm start
```

Abrir http://127.0.0.1:4173. No hace falta compilar HTML/CSS/JS. La tipografía
Manrope se sirve localmente con su licencia OFL. El favicon conserva fondo blanco.

## Supabase

El navegador consulta `GET /api/routes` en el mismo servidor. El servidor usa
`@supabase/supabase-js` para ejecutar `web_route_catalog()`; reconstruye la
respuesta con campos permitidos y conserva una caché de 60 segundos. La URL y
la clave publicable se configuran en el proceso o en
`.transita-private/website.supabase.env`, fuera de `dist/` y de Git:

```dotenv
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=
```

`website/.env.example` documenta las variables. Se aceptan también los nombres
`NEXT_PUBLIC_SUPABASE_URL` y `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` únicamente
en el proceso del servidor. Esta web no los incluye en ningún bundle cliente.
No utiliza claves `service_role` ni secretas. El servidor bloquea archivos
privados y métodos de escritura y limita las conexiones del navegador al mismo origen.

`@supabase/ssr` queda instalado para una futura integración con sesiones SSR.
La web actual es pública y no crea sesiones, usuarios ni cookies de autenticación.
El acceso de la CLI pertenece al entorno de desarrollo y no se entrega a la web.

### Esquema y catálogo

- `supabase/migrations/` contiene la migración generada mediante la CLI.
- `web_catalog_meta` almacena versión, origen, moneda y aviso público.
- `web_routes` almacena destinos, estado de tarifa, orden y publicación.
- Ambas tablas tienen RLS. `anon` y `authenticated` solo consultan los campos
  públicos permitidos; la política de rutas limita la consulta a filas publicadas.
- La función es `security invoker`, con `search_path` fijo. No eleva privilegios.
- No se modifican cuentas, movimientos ni saldos de la app Flutter.

La semilla se genera desde `shared/province_routes.json`:

```powershell
python ../tools/generate_routes.py
```

Para preparar otro proyecto con la CLI fijada en `package-lock.json`:

```powershell
npx supabase login --output-format text
npx supabase link --project-ref <referencia> --output-format text
npx supabase db push --remote=<referencia> --include-seed --skip-vault --yes
```

`--remote` es explícito porque la CLI 3 trabaja localmente por defecto.
Reaplicar la semilla reemplaza los datos públicos de las rutas incluidas;
usarla al inicializar y revisar antes de actualizar un catálogo ya administrado.
`config.toml` describe el entorno local y no despliega la configuración de Auth.

### Verificación y respaldo

`GET /api/health` indica `connected`, `unavailable` o `not_configured`; no revela
credenciales. `X-Catalog-Source` indica `supabase` o `reference`.
Si falta la configuración o falla la consulta, se muestra el catálogo de
referencia con un aviso visible. Ese respaldo no se presenta como lectura de Supabase.
Servir únicamente `dist/` permite la consulta de referencia, pero la integración
con Supabase requiere el servidor Node.

```powershell
npm test
npx supabase db advisors --remote=<referencia> --type security --level warn
```

Las pruebas verifican centavos, datos públicos permitidos, errores del proveedor,
respaldo, bloqueo de archivos privados, rechazo de claves privilegiadas y
coincidencia de la semilla. Se ejecutan localmente con `npm test`; el CI
existente comprueba la sincronización del catálogo compartido.
