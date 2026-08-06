# Changelog

Todas las notas de cambios notables se documentan en este archivo.
El formato sigue [Keep a Changelog](https://keepachangelog.com/es/1.1.0/) y el proyecto usa [Versionado Semántico](https://semver.org/lang/es/).

## [1.0.0] - 2026-08-06

### Añadido
- Backend Express + SQL Server: autenticación JWT (usuario y conductor), registro, cobro de viajes, recarga de puntos, historial y resumen diario.
- Apps Flutter `app_conductor` (cobro con NFC/QR) y `app_usuario` (saldo, recarga y pago con QR).
- Base de datos `bd_cobros` con esquema y datos iniciales (`database.sql`).
- Tests del backend con Jest + Supertest y smoke tests de las apps.
- CI con GitHub Actions (backend y apps Flutter).
- Identidad visual de las apps: iconos y nombres (Yo Conductor / Yo Usuario).
