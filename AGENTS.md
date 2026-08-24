# Instrucciones del proyecto

## Regla de Git/GitHub (OBLIGATORIA)

Este proyecto trabaja SIEMPRE de la mano con GitHub. Después de cualquier
cambio en el código:

1. Crear/verificar una rama `feature/<descripcion>` (si aún no existe).
2. Hacer commit con mensajes **Conventional Commits** en español:
   - `feat:` nueva funcionalidad
   - `fix:` corrección de errores
   - `refactor:` cambios sin cambiar comportamiento
   - `docs:` documentación
   - `chore:` mantenimiento
   - `test:` pruebas
   - `ci:` pipeline/CI
3. `git push` de la rama.
4. Al completar una tarea, abrir **Pull Request** hacia `develop`
   (enlace de compare de GitHub; NO auto-merge sin revisión del usuario).

No dejar nunca cambios sin commitear al finalizar una tarea.

## Flujo de ramas

- `main` → producción.
- `develop` → integración.
- `feature/*` → trabajo nuevo (base: `develop`).

## Verificación antes de cada commit

- Backend: `cd backend && npm test` (todos los tests deben pasar).
- Apps: `flutter analyze` y `flutter test` en `app_conductor` y `app_usuario`.

## Seguridad

- Nunca commitear `backend/.env` (contiene credenciales). Ya está en `.gitignore`.
- Nunca subir secretos, tokens ni contraseñas.

## Datos útiles

- Backend PHP en `api/` servido por XAMPP (Apache) en `http://localhost/transporte_api`
  (junction `htdocs\transporte_api` → `api/`). Base de datos MySQL/MariaDB
  `proyecto_cobros` (phpMyAdmin), esquema en `database/transporte_db.sql`.
- El backend legacy Node + SQL Server (`backend/`, puerto 3000, `bd_cobros`) quedó
  obsoleto: ya no se usa.
- Apps apuntan a `http://127.0.0.1/transporte_api` (en dispositivo físico por USB:
  `adb reverse tcp:80 tcp:80`; en LAN: IP de la PC, ej. `http://192.168.x.x/transporte_api`).
- Contraseña de todos los usuarios/conductores de prueba: `123456`.
