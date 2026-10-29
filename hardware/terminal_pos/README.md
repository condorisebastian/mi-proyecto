# Terminal POS Transita Bolivia

Prototipo de tarjeta propia con saldo de recargas; no usa cuentas bancarias.
El diseño solicitado es https://www.tinkercad.com/things/d8mdIUOUd18/editel.
**Pendiente:** colocar, cablear, guardar y simular el circuito en Tinkercad.
El control del navegador no está conectado a esta sesión. El `.ino` preparado
no acredita que el circuito haya sido creado en el editor.

## Circuito de demostración

Arduino Uno R3, protoboard, LCD 16x2, potenciómetro de 10 kΩ, tres pulsadores,
LED verde, LED rojo, tres resistencias de 220 Ω y piezo.

| Componente | Conexión |
| --- | --- |
| LCD VSS / VDD | GND / 5 V |
| LCD VO | Cursor del potenciómetro; extremos a 5 V y GND |
| LCD RS / E / RW | D12 / D11 / GND |
| LCD D4 / D5 / D6 / D7 | D5 / D4 / D3 / D2 del Arduino |
| LCD luz A / K | 5 V mediante 220 Ω / GND |
| Pulsador tarjeta de prueba | D6 y GND; INPUT_PULLUP |
| Pulsador rechazo | D7 y GND; INPUT_PULLUP |
| Pulsador destino | D8 y GND; INPUT_PULLUP |
| LED verde | D9 → 220 Ω → ánodo; cátodo a GND |
| LED rojo | D10 → 220 Ω → ánodo; cátodo a GND |
| Piezo | Positivo a A0; negativo a GND |

Conectar entre los pares opuestos de los pulsadores; los dos terminales de cada
par están unidos internamente. Todos los componentes comparten GND. Alimentar
por USB regulado; el vehículo requiere alimentación regulada y protegida.

Pegar `terminal_pos.ino` en el modo Texto y simular. Hay Bs 25.50 ficticios.
Un botón alterna La Guardia (Bs 8.00) y El Torno (Bs 8.50); otro simula acercar
una tarjeta y otro simula rechazo. Mantener presionado no descuenta de nuevo.
El monitor serial a 9600 acepta A (tarjeta), R (rechazo), T (destino) y C
(recarga ficticia de Bs 5.00). Ninguna acción del circuito modifica saldo real.

## Terminal y tarjetas físicas

La tablet Android propuesta es de 8–10 pulgadas con NFC y ejecuta Flutter.
Arduino Uno controla señales y pantalla de estado; no ejecuta Flutter.
La app usa el NFC integrado; el lector externo y el enlace USB con Arduino
requieren elegir y probar hardware y adaptadores y todavía no están integrados.

Se ha preparado soporte para NTAG 424 DNA con SDM, mediante un registro NDEF
MIME `application/vnd.transita.card` con contenido ASCII:

`TRANSITA1:<UID 14 hex>:<contador 6 hex little-endian>:<MAC 16 hex>`.

La emisión física requiere personalizar las tarjetas: UID y contador espejados,
MAC con entrada vacía (`SDMMACInputOffset == SDMMACOffset`), claves distintas,
aleatorias y protegidas por tarjeta; configuración y archivo no escribibles
sin autenticación. Una tarjeta NDEF común o un UID estático no cumplen este
protocolo. Las claves no se incluyen en la app, placa, sitio ni repositorio.
SDM autentica el mensaje; se necesita evaluar también robo y retransmisión.

Referencia: [NXP AN12196](https://www.nxp.com/docs/en/application-note/AN12196.pdf),
secciones 3.3 y 3.4.4.2.1. Sus vectores públicos se usan en pruebas, no en producción.
La personalización y la lectura de tarjetas físicas siguen pendientes.

## Servicio de cobros y activación

`transita_bolivia/functions` verifica identidad de terminal, App Check, tarjeta,
MAC, contador, propietario, conductor, importe, cantidad y saldo. El descuento,
contador, recibo y transacción se guardan juntos; la misma referencia no descuenta
otra vez. No admite tarjetas bancarias. Usa `usuarios.puntos`, el mismo saldo
que las recargas de la app Firebase.

**El POS está desactivado:** Flutter usa `ENABLE_POS=false` y el servidor
`POS_LEDGER_LOCKED=false`. No se desplegaron Functions ni reglas de la nube.
Las reglas actuales son de demostración y permiten mutar saldos desde clientes.
Antes de activar cobros: migrar identidad y QR/recargas al servidor, instalar
clientes compatibles y cerrar todas las escrituras financieras directas.

Preparación operativa pendiente:

1. Configurar Firebase Auth de operadores y App Check. Registrar desde el servidor
   `pos_terminals/<Auth UID>` con `estado: activo`, `conductorId` y `maxAmountCents`.
2. Emitir tarjetas; registrar `nfc_cards/<UID mayúsculas>` con `userId`,
   `estado: activo` y `lastCounter`. Solo el operador puede vincular o bloquear.
3. Guardar el mapa UID→clave SDM de 16 bytes en Secret Manager (`NFC_SDM_KEYS`).
   Claves individuales aleatorias; el servidor rechaza la clave de fábrica nula.
   No imprimir ni versionar ese mapa ni enviarlo por chat.
4. Verificar roles y libro de saldos cerrado en emuladores. Confirmar recursos y
   plan de Firebase antes del despliegue. Activar el servicio y compilar con
   `--dart-define=ENABLE_POS=true` únicamente después de esas verificaciones.
5. Probar tarjetas físicas, céntimos, grupos, bloqueo, saldo insuficiente,
   firma alterada, lecturas repetidas y desconexiones.

El límite por cobro es Bs 1,000.00 y puede reducirse por terminal. Un resultado
incierto conserva la referencia en la pantalla; consultar la misma operación
antes de repetirla. La recuperación después de cerrar la app queda pendiente;
no usar esta versión para operación financiera real.
