# Sistema de Cobro de Transporte

Sistema de cobro para el transporte público (Santa Cruz, Bolivia) con una app Flutter unificada y un backend PHP + MySQL/MariaDB servido por XAMPP.

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
3. Credenciales de BD en `api/config/database.php` (por defecto: root sin clave).
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
| POST   | `/transactions/recharge`          | Recargar saldo                     |
| GET    | `/transactions/user/{userId}`     | Historial del usuario              |
| GET    | `/transactions/summary/{conductorId}` | Resumen diario del conductor   |
| GET    | `/transactions/history/{conductorId}` | Historial diario del conductor |
| GET    | `/health`                         | Health check                       |

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
