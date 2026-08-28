# Transporte API (PHP + MySQL/XAMPP)

API REST del sistema de cobros. Compatible 1:1 con los endpoints del backend legacy
(Node/SQL Server), de modo que las apps Flutter no requieren cambios de contrato.

## Endpoints

| Metodo | Ruta                            | Descripcion                          |
|--------|---------------------------------|--------------------------------------|
| POST   | /auth/register                  | Registro de pasajero                 |
| POST   | /auth/login                     | Login pasajero (ci+password+tipo)    |
| POST   | /auth/register-conductor        | Registro de conductor                |
| POST   | /auth/login-conductor           | Login conductor (licencia+password)  |
| GET    | /users/{id}                     | Perfil/saldo del usuario             |
| POST   | /transactions/pay               | Cobro de viaje                       |
| POST   | /transactions/recharge          | Recarga de saldo                     |
| GET    | /transactions/user/{userId}     | Historial del usuario                |
| GET    | /transactions/summary/{condId}  | Resumen diario del conductor         |
| GET    | /transactions/history/{condId}  | Historial diario del conductor       |
| GET    | /health                         | Health check                         |

## Despliegue en XAMPP

1. Base de datos: importar `database/transporte_db.sql` (phpMyAdmin o CLI).
2. Publicar esta carpeta como `C:\xampp\htdocs\transporte_api`. Opcion recomendada:
   junction para servir directo desde el repo:

   ```cmd
   mklink /J C:\xampp\htdocs\transporte_api <ruta-repo>\api
   ```

3. Configuracion de BD en `config/database.php` (default XAMPP: root sin clave).
4. Probar: http://localhost/transporte_api/health
