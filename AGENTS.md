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

- App unificada: `flutter analyze` y `flutter test` en `transita_bolivia`.

## Seguridad

- Nunca subir secretos, tokens ni contraseñas.
- No hardcodear secretos en código versionado (ej. claves JWT). Preferir variables de entorno.

## Datos útiles

- Backend PHP en `api/` servido por XAMPP (Apache) en `http://localhost/transporte_api`
  (junction `htdocs\transporte_api` → `api/`). Base de datos MySQL/MariaDB
  `proyecto_cobros` (phpMyAdmin), esquema en `database/transporte_db.sql`.
- App unificada en `transita_bolivia/` (pasajero + conductor, tipos: estudiante,
  civil, adulto mayor, discapacitado).
- App apunta a la IP LAN de la PC, ej. `http://192.168.100.7/transporte_api`
  (`lib/config.dart`). Funciona por Wi-Fi sin cable USB; si cambia la IP de la PC,
  actualizar `config.dart` o compilar con
  `--dart-define=API_URL=http://<nueva-ip>/transporte_api`.
- Firewall: regla entrante "XAMPP HTTP 80" ya creada (puerto 80 TCP permitido).
- Contraseña de todos los usuarios/conductores de prueba: `123456`.
