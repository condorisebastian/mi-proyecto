# Transporte API (PHP + MySQL/XAMPP)

API REST del sistema de cobros. Mantiene los contratos de perfiles e historiales.
El pago exige autorización del pasajero y la recarga directa está bloqueada hasta
incorporar verificación del operador/proveedor.

## Endpoints

| Metodo | Ruta                            | Descripcion                          |
|--------|---------------------------------|--------------------------------------|
| POST   | /auth/register                  | Registro de pasajero                 |
| POST   | /auth/login                     | Login pasajero (pin+tipo)            |
| POST   | /auth/register-conductor        | Registro de conductor                |
| POST   | /auth/login-conductor           | Login conductor (pin)                |
| GET    | /users/{id}                     | Perfil/saldo del usuario             |
| POST   | /transactions/pay               | Cobro de viaje                       |
| POST   | /transactions/recharge          | 403: requiere verificación externa   |
| GET    | /transactions/user/{userId}     | Historial del usuario                |
| GET    | /transactions/summary/{condId}  | Resumen diario del conductor         |
| GET    | /transactions/history/{condId}  | Historial diario del conductor       |
| GET    | /health                         | Health check                         |

## Despliegue en XAMPP

1. Base de datos: importar `database/transporte_db.sql` (phpMyAdmin o CLI).
   Si ya existia la BD sin la columna `pin`, importar `database/migration_pin.sql`.
2. Publicar esta carpeta como `C:\xampp\htdocs\transporte_api`. Opcion recomendada:
   junction para servir directo desde el repo:

   ```cmd
   mklink /J C:\xampp\htdocs\transporte_api <ruta-repo>\api
   ```

3. Habilitar explícitamente el entorno local y trasladar los archivos privados:

   ```powershell
   php api/migrate_private_config.php --development
   ```

   El destino por defecto es `<ruta-repo>/.transita-private`, fuera de `api/`.
   La migración verifica la copia antes de retirar un archivo antiguo. Si las
   copias no coinciden, conserva el original y falla sin mostrar su contenido.
   La opción `--development` crea un marcador local ignorado por Git; no copiarlo
   al servidor de producción. El modo local permite el usuario root de XAMPP.
4. Probar: http://localhost/transporte_api/health

## Producción

Establecer `APP_ENV=production` en el proceso PHP. Si no hay variable ni marcador
local, ese es el valor predeterminado. `config/database.php` carga los nombres
descritos en `.env.example`, sin imprimirlos. Los archivos `.env` no se cargan
automáticamente y nunca deben publicarse.

- `JWT_SECRET`: secreto privado de al menos 32 bytes. Producción no lo genera
  automáticamente. Como alternativa, usar `.jwt_secret` en el directorio privado.
- `DB_USER` y `DB_PASS`: usuario limitado con contraseña obligatoria. Producción
  rechaza root. `DB_HOST` y `DB_NAME` permiten seleccionar la base de datos.
- `TRANSPORT_PRIVATE_DIR`: ruta absoluta, fuera de `api/` y del DocumentRoot.
  También se rechazan segmentos relativos y destinos a través de enlaces que
  terminen dentro del directorio publicado.

Para preparar el usuario SQL desde CLI, ejecutar `php api/setup_db_user.php`.
Opcionalmente se pueden suministrar `DB_ADMIN_USER` y `DB_ADMIN_PASS` al proceso
de mantenimiento. Sus credenciales no forman parte de Flutter. El script guarda
la cuenta limitada en `.db_creds.php` dentro del directorio privado; no muestra
la contraseña ni excepciones SQL. Una nueva instalación debe configurar aparte
el secreto JWT y servir la API mediante HTTPS.

Apache necesita `mod_rewrite`, autorización 2.4 y `AllowOverride All` para aplicar
el `.htaccess`. Validar el despliegue con `tools/security/test_apache_access.py`.
No publicar todo el repositorio: solo `api/`. Este endurecimiento no sustituye
la migración pendiente del login por PIN y de los cobros a una identidad y
autorización de producción. El modo Firebase mantiene datos separados de SQL.
