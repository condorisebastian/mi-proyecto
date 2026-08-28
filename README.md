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

- **Pasajero**: 4 tipos (estudiante, civil, adulto mayor, discapacitado), registro, recarga, pago de viaje (QR/NFC), tarjeta, historial.
- **Conductor**: login/registro por licencia, cobro de viajes (QR/NFC), resumen diario, historial.

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

## Credenciales de prueba

Todas las contraseñas de usuarios y conductores son `123456` (definidas en `database/transporte_db.sql`).

- Pasajero de prueba (CI): `1234567`
- Conductor de prueba (licencia): `LIC-12345`

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