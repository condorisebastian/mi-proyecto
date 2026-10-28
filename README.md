# Sistema de Cobro de Transporte

Sistema de cobro para el transporte público (Santa Cruz, Bolivia) con una app Flutter unificada y un backend PHP + MySQL/MariaDB servido por XAMPP.

## Web, Provincias y terminal POS

La web en `website/dist` consulta el catálogo y permite calcular grupos. Su
simulador POS usa saldo ficticio y no accede a cuentas. El catálogo fuente es
`shared/province_routes.json`: 29 destinos de las 15 provincias de Santa Cruz.
Todos los municipios muestran «Tarifa por verificar», incluidos La Guardia y
El Torno. No se generan cobros provinciales hasta verificar sus importes.
No se presentan precios históricos del Decreto 494 como tarifas actuales.

El original es `logo_transitabolivia.png`. La versión sin fondo es
`logo_transitabolivia_transparente.png` y se usa en la app y la web; la variante
cuadrada `transita_bolivia/assets/images/logo_icon.png` evita deformar los iconos.
Se generaron con la herramienta integrada `image_gen`: «Quitar únicamente el
fondo y preservar símbolo, colores, texto y proporciones»; para el icono,
«centrar el mismo logo en un lienzo cuadrado transparente sin estirar ni recortar».
La portada recorre automáticamente las 15 provincias cada tres segundos, con
fundido de 650 ms y precarga de la siguiente fotografía para evitar parpadeos,
pausa manual y respeto por la preferencia de movimiento reducido. Incluye
fotografías locales, controles accesibles, selección de provincia y créditos.
Las fuentes revisadas están en `website/photo_sources.json`; ejecutar
`python tools/download_destination_photos.py` para recuperar las imágenes y
sus atribuciones. La página `credits.html` enlaza cada autor, archivo y licencia.

Ejecutar `python tools/generate_routes.py` después de editar el catálogo;
sincroniza Flutter, web y Functions. PHP publica `GET /catalog/routes` y valida
los importes provinciales al cobrar. La app muestra Provincias en pasajero y
conductor, admite grupos y conserva los cobros urbanos y personalizados.

El POS NFC es de circuito cerrado con saldo de recargas, sin cuentas bancarias.
Las pantallas y el backend están preparados, pero los cobros están desactivados
hasta cerrar las reglas de demostración, activar identidades/terminales,
desplegar Functions y emitir tarjetas. La web también identifica NFC como
funcionalidad en preparación. No se modificaron las reglas de producción.

Ver [circuito, conexiones y requisitos de activación](hardware/terminal_pos/README.md).
El circuito de Tinkercad, el hardware físico y la depuración en teléfono siguen
pendientes de acceso y pruebas; preparar archivos no equivale a simularlos allí.

Comprobaciones adicionales:

```text
python tools/generate_routes.py --check
node --test transita_bolivia/functions/test/payments.test.js website/test/fare_math.test.mjs
```

## Arquitectura

```
mi-proyecto/
├── api/                  # API REST (PHP + MySQL/MariaDB, XAMPP)
│   ├── config/           # Conexión a la BD
│   ├── src/              # db, helpers (JWT), rutas (auth, users, transactions)
│   └── README.md         # Endpoints y despliegue
├── database/
│   └── transporte_db.sql # Esquema y datos de prueba de `proyecto_cobros`
└── transita_bolivia/     # App Flutter unificada (pasajero + conductor)
```

## Requisitos

- XAMPP (Apache + PHP + MySQL/MariaDB)
- Flutter 3.x para la app

## Configuración del backend

1. Importar `database/transporte_db.sql` desde phpMyAdmin (crea la BD `proyecto_cobros` con datos de prueba).
   - Si ya tenías la BD creada con el esquema anterior (sin PIN), importar en su
     lugar `database/migration_pin.sql`, que agrega la columna `pin` sin borrar datos.
2. Publicar la API en `htdocs` (junction recomendado, sirve directo desde el repo):
   ```
   mklink /J C:\xampp\htdocs\transporte_api <ruta-del-repo>\api
   ```
3. Para desarrollo local, ejecutar `php api/migrate_private_config.php --development`.
   La configuración privada queda en `.transita-private/`, fuera de `api/` e
   ignorada por Git. El modo local conserva la compatibilidad con XAMPP.
   En producción usar `APP_ENV=production`, un usuario limitado de BD con clave
   y un secreto JWT de al menos 32 bytes, suministrados por el servidor.
4. Verificar: `http://localhost/transporte_api/health`

### Endpoints principales

| Método | Ruta                              | Descripción                        |
|--------|-----------------------------------|------------------------------------|
| POST   | `/auth/register`                  | Registrar pasajero                 |
| POST   | `/auth/login`                     | Login de usuario                   |
| POST   | `/auth/register-conductor`        | Registrar conductor                |
| POST   | `/auth/login-conductor`           | Login de conductor                 |
| GET    | `/users/{id}`                     | Datos/saldo de un usuario          |
| POST   | `/transactions/pay`               | Cobrar un viaje                    |
| POST   | `/transactions/recharge`          | Bloqueado hasta verificación de recarga |
| GET    | `/transactions/user/{userId}`     | Historial del usuario              |
| GET    | `/transactions/summary/{conductorId}` | Resumen diario del conductor   |
| GET    | `/transactions/history/{conductorId}` | Historial diario del conductor |
| GET    | `/health`                         | Health check                       |

## Seguridad: primera etapa

La primera etapa protege el backend PHP y añade verificaciones automáticas.
No convierte el entorno Firebase de demostración en una instalación de producción.

- Apache bloquea configuración, archivos ocultos, código interno, pruebas y
  scripts de mantenimiento. Los scripts de configuración solo admiten CLI.
- JWT y credenciales SQL se leen de variables del proceso o de un directorio
  privado fuera del directorio publicado. `api/.env.example` enumera las
  variables; copiar ese archivo no configura automáticamente Apache/PHP.
- Producción es el modo predeterminado: requiere un secreto configurado y
  rechaza el usuario SQL root y las contraseñas vacías. El entorno local se
  habilita explícitamente con la migración indicada arriba.
- Un conductor no puede descontar el saldo de un pasajero. El pago PHP requiere
  el token del propio pasajero. La recarga directa PHP devuelve 403: aún falta
  implementar su verificación por operador/proveedor. El chat financiero de
  demostración sigue usando Firebase; no acredita la base de datos SQL.
- Los errores de acceso no reproducen el PIN, el CI ni el perfil de la cuenta.
- Gitleaks revisa los archivos versionables y el historial Git. La salida se
  limita a ubicación y regla, sin imprimir claves ni coincidencias. Solo se
  exceptúa el identificador público de Firebase en sus archivos de cliente;
  las claves privadas dentro de esos archivos siguen detectándose.
- CI comprueba autorización HTTP, configuración privada y las restricciones
  sobre un Apache real, además de las pruebas funcionales Flutter y PHP.

Para ejecutar las verificaciones locales:

```powershell
php api/tests/security_test.php
php api/tests/money_test.php
python tools/security/test_api_http.py
# Configurar GITLEAKS_BIN con la ruta del ejecutable Gitleaks 8.30.1 verificado.
python tools/security/test_secret_scan.py
python tools/security/scan_secrets.py
python tools/security/scan_secrets.py --history
# Con Apache local iniciado y api/ publicado en /transporte_api:
python tools/security/test_apache_access.py http://localhost/transporte_api
```

Pendiente para producción: autenticar cada cuenta con Firebase Authentication,
asignar roles desde el servidor, trasladar la autorización financiera a un
backend confiable, restringir Firestore por propietario, proteger las sesiones,
exigir HTTPS y configurar firma de producción y App Check. Las reglas actuales
siguen siendo de demostración. La migración debe instalar y probar los clientes
compatibles antes de retirar ese acceso; no desplegar reglas incompatibles sobre
los teléfonos actuales.

## App Flutter (transita_bolivia)

App unificada para pasajeros y conductores con selección de rol al iniciar:

- **Pasajero**: 4 tipos (estudiante, civil, adulto mayor, discapacitado), registro, chat de recargas con el operador, pago individual o grupal por QR e historial.
- **Conductor**: login/registro por PIN, cobro por QR con cuadrícula de categorías e iconos, cantidad de pasajes editable, alerta sonora y visual, resumen y chat de retiros diarios. El QR aparece al tocar una categoría. Solo la sección **Pago** tiene un campo de monto total personalizado y el botón **MOSTRAR QR**.
- **Administrador**: bandeja Chats, conversación en vivo y confirmación/rechazo de solicitudes de recarga y retiro. Su acceso no se muestra en la selección principal de roles.

Tarifas del prototipo: civil **Bs 3.50**; estudiante, adulto mayor y persona
con discapacidad **Bs 1.00**. Una persona puede pagar hasta 50 pasajes de una
misma categoría mediante un solo QR. Los cálculos se hacen en centavos enteros;
los campos existentes `puntos` siguen representando bolivianos y admiten
valores decimales en Firebase, JSON y MySQL (`DECIMAL`). Los saldos enteros
anteriores siguen siendo válidos. Recargas y retiros también admiten centavos.
En **Cobrar → Pago**, el conductor puede escribir la cantidad de pasajes y el
monto total acordado (por ejemplo, 3 pasajes por Bs 7.50), y pulsar **MOSTRAR QR**.
El importe ingresado ya es el total: no se multiplica de nuevo por la cantidad.
El pasajero ve que es un monto personalizado y lo confirma antes del descuento.
Las cuatro categorías conservan sus tarifas y generan el QR automáticamente.

El acceso precarga el carnet del perfil de prueba y recuerda el último CI de
cada perfil tras un acceso correcto, sin guardar el PIN. El usuario puede
editar el carnet para acceder con otra cuenta.

Con Apache corriendo y la API publicada:

```
cd transita_bolivia
flutter pub get
flutter run
```

La app apunta por defecto a la IP LAN de la PC, ej.
`http://192.168.100.7/transporte_api` (ver `transita_bolivia/lib/config.dart`).
Funciona por Wi-Fi sin cable USB; solo se requiere:

- PC y teléfono en la misma red Wi-Fi.
- Apache y MySQL corriendo en XAMPP.
- Regla de firewall entrante para el puerto 80
  (`netsh advfirewall firewall add rule name="XAMPP HTTP 80" dir=in action=allow protocol=TCP localport=80`).

Si cambia la IP de la PC, actualizar el `defaultValue` en
`transita_bolivia/lib/config.dart`, o compilar con
`--dart-define=API_URL=http://<nueva-ip>/transporte_api`.

## Modo Firebase (predeterminado)

La app usa Cloud Firestore por defecto para sincronizar los dos teléfonos
(login/registro por PIN, recargas, pagos, resumen diario y soporte).
El modo PHP/MySQL se selecciona con `--dart-define=USE_FIREBASE=false`.
Ambos modos almacenan datos por separado; no hay sincronización entre ellos.

```
cd transita_bolivia
flutter run --dart-define=USE_FIREBASE=true
```

La app intenta crear una identidad anónima de Firebase Auth si el proveedor está
habilitado; el acceso de la aplicación sigue siendo por PIN. Las reglas actuales
son para demostración y deben reforzarse antes de producción. Están versionadas y se despliegan desde
`transita_bolivia/`:

```
firebase deploy --only firestore --project transita-bolivia
```

Archivos: `transita_bolivia/firestore.rules` y `firestore.indexes.json`. Para
sembrar los PIN de prueba en Firestore: `node tools/firebase/seed_pins.js`
(requiere `GOOGLE_APPLICATION_CREDENTIALS`).

### Prueba en dos teléfonos

1. Instalar la misma compilación Firebase en ambos equipos, con acceso a internet.
2. Samsung A70 (`R58M54T79VR`): pasajero estudiante, PIN `1234`.
3. Tecno BG7 (`11424153CR013112`): conductor, PIN `5678`.
4. Comprobar que el pasajero tenga saldo. En **Chat → Solicitar recarga**, enviar
   monto y referencia. En **Administración → Chats**, el operador responde y
   confirma el pago verificado; entonces se acreditan los puntos una sola vez.
5. En el Tecno, elegir **Cobrar**, escribir la cantidad de pasajes y tocar
   **Estudiante** para usar la tarifa fija. Para un cobro personalizado, escribir
   también el **Monto total (Bs)** en **Pago** y pulsar **MOSTRAR QR**.
6. En el Samsung, elegir **Pagar → Escanear QR del conductor → Pagar**.
7. El Samsung muestra el comprobante y el nuevo saldo. El Tecno emite dos tonos,
   vibra y muestra **PAGO EXITOSO** sobre el QR, con el importe y el pasajero.
   El historial y el resumen se actualizan en vivo.

En el chat del conductor se muestra su recaudación diaria disponible, lo reservado
y lo retirado. El calendario permite consultar días anteriores y solicitar su
saldo pendiente, sin perderlo al cambiar de día. **Solicitar retiro** reserva el monto; el operador confirma solo
después de entregar el dinero. Rechazar libera la reserva. Los retiros no pueden
superar los cobros exitosos disponibles de ese conductor y día. La confirmación
registra la operación; la app no ejecuta transferencias bancarias.

Los chats usan `chats/{id}/mensajes`, `solicitudes_financieras` y `liquidaciones`.
Desplegar las reglas antes de probar la nueva sección:
`firebase deploy --only firestore:rules --project transita-bolivia`.
No requieren índices compuestos nuevos. Las solicitudes tienen estados
`pendiente`, `aprobada` y `rechazada`, con respuesta y registro de la operación.

Para usar el cobro grupal en el backend PHP/MariaDB existente, ejecutar una vez
`database/migration_pago_grupal.sql`; una instalación nueva ya incluye la columna.

Mantener la app del conductor abierta y el volumen multimedia audible. Este aviso
es una alarma dentro de la app; no usa notificaciones push con la aplicación cerrada.
Un pasajero solo puede pagar una vez cada QR: para otro viaje, cerrar el QR y
generar uno nuevo. Los reintentos no descuentan otra vez y el historial antiguo
no provoca alarmas al abrir la app. El pago requiere conexión y confirmación del
servidor; no se anuncia como exitoso un pago pendiente sin internet.

## Credenciales de prueba

El acceso es por **PIN único de 4 dígitos** (ya no se usa CI ni contraseña).
Los PIN están en `database/transporte_db.sql` (backend PHP) y en Firestore
(`usuarios`/`conductores`, campo `pin`) para el modo Firebase.

- Pasajero estudiante: `1234` (Sebastian)
- Pasajero civil: `2345` (Maria) / `4567` (Ana)
- Pasajero adulto mayor: `3456` (Pedro)
- Conductor: `5678` (Juan) / `6789` (Carlos)
- Administrador: `0000`

## Tests

```
cd transita_bolivia && flutter analyze && flutter test
```

## Flujo de trabajo con Git

- `main` — rama de producción.
- `develop` — integración.
- `feature/*` — trabajo nuevo; se integra vía Pull Request a `develop`.

## Licencia

MIT. Ver [LICENSE](LICENSE).
