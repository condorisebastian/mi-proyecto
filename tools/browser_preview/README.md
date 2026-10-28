# Vista interactiva de Transita Bolivia

Muestra las pantallas originales de Flutter en un marco de teléfono dentro del
navegador: Inicio, Perfiles, Provincias y Cobrar. Se puede recorrer la interfaz,
filtrar destinos, cambiar cantidades y mostrar QR de demostración.

La vista no inicializa Firebase ni restaura sesiones. El conductor tiene ID 0,
por lo que sus QR son rechazados por la app de pagos. Los accesos muestran un
mensaje de demostración y no consultan cuentas. Esta vista no sustituye las
pruebas en Android ni prueba lectores NFC.

Desde este directorio:

```powershell
flutter pub get --offline
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8766 --dart-define=USE_FIREBASE=false --dart-define=API_URL=http://127.0.0.1:9/preview --dart-define=ENABLE_POS=false
```

Abrir `http://127.0.0.1:8766/`. El botón de la página web apunta al sitio servido
por XAMPP en `http://127.0.0.1/transita_bolivia_web/`.

La dependencia `../../transita_bolivia` reutiliza directamente los widgets de la
app. El logo en `assets/images/` es una copia de su PNG transparente para que
las rutas de recursos coincidan en ambas aplicaciones.
