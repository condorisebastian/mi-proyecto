# Changelog

Todas las notas de cambios notables se documentan en este archivo.
El formato sigue [Keep a Changelog](https://keepachangelog.com/es/1.1.0/) y el proyecto usa [Versionado Semántico](https://semver.org/lang/es/).

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