# Changelog

Todas las notas de cambios notables se documentan en este archivo.
El formato sigue [Keep a Changelog](https://keepachangelog.com/es/1.1.0/) y el proyecto usa [Versionado Semántico](https://semver.org/lang/es/).

## [Unreleased]

### Añadido
- Cuadrícula 2×2 con iconos y selector de cantidad para pagar varios pasajes con
  un mismo QR. Comprobante, historial, avisos y resumen incluyen la cantidad.
- Chat de recargas del pasajero en lugar de la recarga automática, chat de retiros
  diarios del conductor y bandeja de conversaciones para el administrador.
- Confirmación única de solicitudes, reservas de retiros y liberación al rechazar.
- Eliminados los emojis de las etiquetas; se usan iconos Material en la interfaz.

### Corregido
- Cobro exclusivo por QR: retirados pantalla, permisos y paquetes NFC.
- Aviso de pago confirmado en el conductor con dos tonos Android, vibración y
  aviso visual sobre el QR; se descartan caché, historial y eventos duplicados.
- Un QR no puede descontar dos veces al mismo pasajero. Se validan saldo,
  cuentas activas y tarifa; pagos y recargas usan transacciones atómicas.
- Firebase predeterminado para la prueba Samsung pasajero / Tecno conductor.
- Cancelar una recarga ya no añade puntos; se identifica como demostración.
- Compartir resumen, signos del historial del conductor y sesiones entre modos.

### Añadido
- Acceso por **PIN único de 4 dígitos** para pasajeros y conductores (reemplaza CI, contraseña y licencia).
- Integración Firebase opcional (Firestore) con `--dart-define=USE_FIREBASE=true`; login/registro por PIN en la nube.
- Reglas e índices de Firestore versionados (`firestore.rules`, `firestore.indexes.json`) y desplegados.
- Script `database/migration_pin.sql` para actualizar una BD existente sin perder datos.
- Script `tools/firebase/seed_pins.js` para sembrar PINs en Firestore.

### Cambiado
- `/auth/login` y `/auth/login-conductor` reciben `pin` (antes ci/licencia + password).
- `ci` pasa a ser opcional en `pasajeros` y `conductores`.
- Se elimina la dependencia `firebase_auth` de la app.

### Eliminado
- Script `tools/firebase/create_auth_users.js` (ya no se usa Firebase Auth).

## [2.0.0] - 2026-08-27

### Añadido
- App unificada `transita_bolivia` (pasajero + conductor) con selección de rol al iniciar.
- Nuevo tipo de pasajero **discapacitado** (además de estudiante, civil y adulto mayor).
- Logo oficial como icono de launcher (Android/iOS).
- Backend PHP actualizado para el tipo `discapacitado` (ENUM MySQL, auth, transactions).
- CI actualizado: lint de `api/` + `flutter analyze && flutter test` de `transita_bolivia`.

### Cambiado
- Las apps `app_conductor` y `app_usuario` fueron reemplazadas por `transita_bolivia`.
- Sesiones separadas entre pasajero y conductor (evita pisotearse entre sí).

### Eliminado
- Backend legacy Node + SQL Server (`backend/`, puerto 3000, `bd_cobros`).
- App `app_conductor` y `app_usuario` (fusionadas en `transita_bolivia`).
- Carpeta `logo_app` (el logo ahora vive en `transita_bolivia/assets/images/`).
- Ramas `feature/*` ya fusionadas en `develop`.

## [1.0.0] - 2026-08-06

### Añadido
- Backend Express + SQL Server: autenticación JWT (usuario y conductor), registro, cobro de viajes, recarga de puntos, historial y resumen diario.
- Apps Flutter `app_conductor` (cobro con NFC/QR) y `app_usuario` (saldo, recarga y pago con QR).
- Base de datos `bd_cobros` con esquema y datos iniciales (`database.sql`).
- Tests del backend con Jest + Supertest y smoke tests de las apps.
- CI con GitHub Actions (backend y apps Flutter).
- Identidad visual de las apps: iconos y nombres (Yo Conductor / Yo Usuario).
