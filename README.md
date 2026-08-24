# Sistema de Cobro de Transporte

Sistema de cobro para el transporte público (Santa Cruz, Bolivia) con dos apps Flutter y un backend PHP + MySQL/MariaDB servido por XAMPP.

## Arquitectura

```
mi-proyecto/
├── api/                  # API REST (PHP + MySQL/MariaDB, XAMPP)
│   ├── config/           # Conexión a la BD
│   ├── src/              # db, helpers (JWT), rutas (auth, users, transactions)
│   └── README.md         # Endpoints y despliegue
├── database/
│   └── transporte_db.sql # Esquema y datos de prueba de `proyecto_cobros`
├── app_conductor/        # App Flutter del conductor (cobro QR/NFC)
├── app_usuario/          # App Flutter del pasajero (saldo, recarga, QR)
└── backend/              # (OBSOLETO) backend legacy Node + SQL Server; ya no se usa
```

## Requisitos

- XAMPP (Apache + PHP + MySQL/MariaDB)
- Flutter 3.x para las apps

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

## Apps Flutter

Con Apache corriendo y la API publicada:

```
cd app_conductor   # o app_usuario
flutter pub get
flutter run
```

Las apps apuntan por defecto a `http://127.0.0.1/transporte_api`
(`lib/config.dart`). En dispositivo físico por USB usar `adb reverse tcp:8080 tcp:80`
y compilar con `--dart-define=API_URL=http://127.0.0.1:8080/transporte_api`;
en LAN usar la IP de la PC (ej. `http://192.168.x.x/transporte_api`).

## Credenciales de prueba

Todas las contraseñas de usuarios y conductores son `123456` (definidas en `database/transporte_db.sql`).

## Tests

```
cd app_conductor && flutter analyze && flutter test
cd app_usuario && flutter analyze && flutter test
```

## Flujo de trabajo con Git

- `main` — rama de producción.
- `develop` — integración.
- `feature/*` — trabajo nuevo; se integra vía Pull Request a `develop`.

## Licencia

MIT. Ver [LICENSE](LICENSE).
