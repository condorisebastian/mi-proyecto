# Sistema de Cobro de Transporte

Sistema de cobro para el transporte público (Santa Cruz, Bolivia) con dos apps Flutter y un backend Express + SQL Server.

## Arquitectura

```
mi-proyecto/
├── backend/            # API REST (Node.js + Express + SQL Server)
│   ├── src/            # db, rutas (auth, users, transactions)
│   ├── tests/          # Tests con Jest + Supertest
│   ├── database.sql    # Esquema y datos iniciales de bd_cobros
│   └── .env.example    # Variables de entorno de ejemplo
├── app_conductor/      # App Flutter del conductor (cobro NFC/QR)
└── app_usuario/        # App Flutter del pasajero (saldo, recarga, QR)
```

## Requisitos

- Node.js 18+ y npm
- SQL Server (o Express) con autenticación mixta habilitada
- Flutter 3.x para las apps

## Configuración del backend

1. Crear la base de datos con `backend/database.sql`.
2. Copiar `backend/.env.example` a `backend/.env` y completar las credenciales:
   ```
   PORT=3000
   DB_SERVER=localhost\SQLEXPRESS
   DB_NAME=bd_cobros
   DB_USER=sa
   DB_PASSWORD=tu_password
   JWT_SECRET=tu_secret
   ```
3. Instalar y arrancar:
   ```
   cd backend
   npm install
   npm start
   ```
   La API queda en `http://localhost:3000`.

### Endpoints principales

| Método | Ruta                              | Descripción                        |
|--------|-----------------------------------|------------------------------------|
| POST   | `/api/auth/register`              | Registrar usuario                 |
| POST   | `/api/auth/login`                 | Login de usuario                  |
| POST   | `/api/auth/login-conductor`       | Login de conductor                |
| GET    | `/api/users/:id`                  | Datos de un usuario               |
| POST   | `/api/transactions/pay`           | Cobrar un viaje                   |
| POST   | `/api/transactions/recharge`      | Recargar puntos                   |
| GET    | `/api/transactions/user/:userId`  | Historial del usuario             |
| GET    | `/api/transactions/summary/:conductorId` | Resumen diario del conductor |
| GET    | `/api/transactions/history/:conductorId` | Historial diario del conductor |
| GET    | `/api/health`                     | Health check                      |

## Apps Flutter

Con el backend corriendo y el teléfono en la misma red:

```
cd app_conductor   # o app_usuario
flutter pub get
flutter run
```

El servidor usa una IP fija (`http://192.168.100.7:3000/api`) configurada en
`lib/services/api_service.dart` y `lib/services/auth_service.dart` de ambas apps.
Si tu IP cambia, actualiza esos archivos.

## Credenciales de prueba

Todas las contraseñas de usuarios y conductores son `123456` (definidas en `database.sql`).

## Tests

```
cd backend && npm test        # Tests del backend
cd app_conductor && flutter test   # Tests de la app conductor
cd app_usuario && flutter test     # Tests de la app usuario
```

## Flujo de trabajo con Git

- `main` — rama de producción.
- `develop` — integración.
- `feature/*` — trabajo nuevo; se integra vía Pull Request a `develop`.

## Licencia

MIT. Ver [LICENSE](LICENSE).
