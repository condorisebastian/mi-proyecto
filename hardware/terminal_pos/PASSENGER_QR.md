# QR del pasajero para ESP32-CAM

La app ofrece **Pagar → Con QR → Mostrar mi QR**. La imagen se genera sin
esperar una consulta de red y permanece visible aproximadamente 15 segundos.
Al vencer, cambiar de cuenta o pasar la app a segundo plano, deja de mostrarse.
El pasajero puede generar otro frente al lector. No se renueva en segundo plano.

Quince segundos es el valor inicial de diseño: cinco dejan poco margen para
alinear el teléfono, enfocar y leer con una ESP32-CAM. Debe ajustarse tras medir
el lector físico, la iluminación y el tiempo de respuesta del servidor.

## Protocolo de lectura de prueba

```text
MP-ID1:D:<backend>:<id_pasajero>:<vence_unix_segundos>:<nonce_hex_32>
```

- `D` identifica una demostración de identificación. **No autoriza pagos**.
- Backend `F` corresponde a Firebase; `P`, al backend PHP. Los IDs no se mezclan.
- El nonce usa 16 bytes aleatorios nuevos por generación.
- El código no incluye PIN, CI, nombre, saldo ni claves de API.
- La fecha de vencimiento usa UTC. El lector necesita hora sincronizada para
  comprobar la ventana; cambiar el reloj del teléfono no constituye autorización.
- `PassengerQr.tryParse` documenta y prueba la estructura y el vencimiento.

Este código no está firmado: un lector no debe confiar en el ID recibido para
descontar saldo. El prefijo difiere del QR de cobro del conductor y de la prueba
NFC; los flujos de cobro actuales no lo aceptan como una orden de pago.

## Antes de aceptar cobros reales

El servidor deberá emitir o vincular un token a una sesión verificada, conocer
la terminal y el conductor autorizados, comprobar el importe y exigir la
confirmación del pasajero. La caducidad y el uso único se validarán en el
servidor de forma atómica junto al descuento y al comprobante. Reintentar una
operación confirmada deberá devolver el mismo resultado sin descontar dos veces.

No habilitar estos cobros sobre las reglas de demostración de Firestore. El
servicio POS existente permanece sin activar; esta tarea no despliega Functions,
no modifica saldos y no configura ni flashea una ESP32-CAM física.

El siguiente ensayo de hardware consiste en leer el texto del QR desde la
pantalla, comprobar resolución, foco, orientación y luz, y medir lecturas
repetidas y vencidas. No conectar el resultado directamente a una operación
de débito del cliente.
