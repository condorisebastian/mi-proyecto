# Mi Pasaje Atención

Portal independiente para operadores y supervisión. Registra clientes ficticios,
verifica solicitudes estudiantiles contra un padrón de prueba, recarga puntos,
bloquea cuentas y registra el seguimiento de casos. Cada acción tiene un responsable.

**Solo demostración:** los puntos no representan dinero. Los registros de este
portal están en Supabase y no modifican las cuentas, PIN ni saldos de la app móvil
que actualmente usa Firebase. No hay cuentas bancarias, pasarela de pago ni
validación oficial de instituciones educativas conectadas.

## Abrir

Requiere Node.js 22.13 o posterior. Desde `operator_portal/`:

```powershell
npm ci
npm start
```

Abrir **http://127.0.0.1:4174/**. La configuración del proceso se carga desde
`.transita-private/operator-portal.env`, fuera de `public/` y de Git.
`.env.example` enumera las variables, sin valores privados.

Los accesos de demostración están únicamente en
`.transita-private/operator-demo-accounts.json`. Se generan claves aleatorias de
24 caracteres; no hay contraseñas compartidas ni claves escritas en el código.

## Cuentas y permisos

| Cuenta de demostración | Rol | Funciones |
| --- | --- | --- |
| `supervisor.demo` | Supervisión | Operaciones de atención, historial general y administración de operadores |
| `ana.atencion` | Operador | Clientes, documentos, recargas, bloqueos y casos; consulta de sus propias operaciones |
| `luis.atencion` | Operador | Mismos permisos de atención, con sesión y auditoría propias |
| `maria.atencion` | Operador | Creada desde el portal durante la verificación funcional |

Supervisión crea nuevas cuentas y entrega la clave que se muestra una sola vez.
Desactivar una cuenta impide nuevas solicitudes con una sesión que ya estuviera
abierta. Un operador no puede crear otras cuentas ni elevar su rol. El supervisor
no puede desactivarse a sí mismo. No se eliminan clientes ni operaciones.

## Atención de clientes

- Buscar por nombre, documento ficticio o número de registro; filtrar activos,
  bloqueados y solicitudes pendientes. Los listados enmascaran el documento.
- Registrar nombres, apellidos, documento `DEMO-` más siete números, nacimiento,
  teléfono de referencia opcional y categoría solicitada. El saldo inicial es cero.
- Consultar datos, billetera, comprobantes, documentos e historial de atención.
- Bloquear o desbloquear con un motivo obligatorio de al menos diez caracteres.
  No se permiten recargas a clientes bloqueados.
- Abrir un caso, asignarse su atención y registrar notas con estado nueva,
  en curso o resuelta.

La semilla tiene seis clientes ficticios de los cuatro tipos de pasajero. La
verificación funcional deja una recarga de 0.50 puntos para Diego Molina y la
solicitud de Lucía Rojas aprobada con documentos expresamente ficticios. Desde la
interfaz se registró además a Valeria Suárez, se aprobaron sus documentos de prueba
y se le recargaron 0.50 puntos: esta instalación tiene siete clientes ficticios.

## Validación estudiantil

La categoría solicitada y la efectiva son distintas. Registrar un estudiante lo
deja **pendiente**, con categoría efectiva **Civil**. Para aprobar deben cumplirse
todas estas condiciones en el servidor:

1. Coincidencia de nombres, documento, institución, ID estudiantil, matrícula y
   carnet con el padrón académico ficticio.
2. Registro académico activo y vigente.
3. Carnet y comprobante de matrícula adjuntos a la revisión actual.
4. Confirmación del operador de haber contrastado identidad, fotografía y documentos.
5. Motivo de la decisión, cuenta activa y solicitud todavía pendiente.

Se permiten PNG, JPG y PDF de hasta 5 MB; el servidor revisa la firma del contenido,
genera nombres internos, calcula su hash y los guarda fuera de los archivos públicos.
Las descargas requieren sesión. Los PDF se entregan como archivos adjuntos.

Los documentos de ejemplo dicen **FICTICIO** y **sin validez académica ni legal**.
El botón para cargarlos no aprueba la solicitud. Una renovación exige nuevos
documentos y conserva las revisiones anteriores. Al vencer la verificación, la
categoría efectiva vuelve a Civil.

| Ejemplo del padrón | Resultado esperado |
| --- | --- |
| Lucía Rojas, `DEMO-1000001`, sufijo `001` en EST/MAT/CAR | Matrícula vigente; requiere ambos documentos y revisión |
| Mateo Vargas, `DEMO-1000002`, sufijo `002` | Vigente; pendiente para probar el flujo |
| Camila Flores, `DEMO-1000003`, sufijo `003` | Registro inactivo y vencido; no se puede aprobar |
| Valeria Suárez, `DEMO-1000004`, sufijo `004` | Registro académico para probar un alta nueva |

Los identificadores completos tienen la forma `EST-DEMO-001`, `MAT-DEMO-001` y
`CAR-DEMO-001`; la institución es **Instituto Demo del Oriente**. Para validar
estudiantes reales se necesita un padrón o convenio oficial y un proceso de revisión
institucional; esta demo no afirma comprobar matrícula real ni realiza OCR.

## Recargas

Los cálculos usan centésimas enteras de punto. Se aceptan **0.50 a 1000 puntos** por
operación en incrementos de 0.50, con un límite inicial de **5000 puntos diarios**
por operador, calculado en horario de Bolivia. Cada recarga exige:

- Cliente activo, confirmación del nombre/documento y sus últimos cuatro dígitos.
- Confirmación de que son puntos ficticios.
- Referencia única con prefijo `DEMO-` e identificador de solicitud.
- Validación de monto y límite diario en la misma transacción que actualiza saldo,
  crea el comprobante y registra al operador.

Un reintento de la misma solicitud devuelve el comprobante original. Solicitudes
simultáneas no acreditan dos veces. Una referencia repetida con otra solicitud se
rechaza y no altera el saldo. La interfaz conserva el identificador pendiente al
cambiar de cliente o recargar la página en la misma pestaña; si un resultado es
incierto, consultar movimientos antes de iniciar una operación distinta.

El comprobante incluye referencia, cliente, puntos, saldo posterior, fecha y
operador. Se puede consultar e imprimir desde el portal.

## Preparación de otra instalación

La migración `website/supabase/migrations/20261127145432_operator_portal.sql`
contiene el esquema; `database/schema.sql` conserva la misma definición para
instalación y verificación. No editar migraciones ya publicadas: crear otra para
cambios posteriores.

Con la CLI autenticada y el proyecto correcto enlazado, aplicar la migración usando
el flujo del proyecto. Después preparar la demo explícitamente:

```powershell
npm run prepare-demo
```

El preparador comprueba que el proyecto enlazado y la configuración coincidan,
crea las cuentas ficticias que falten y conserva las existentes. La semilla no
sobrescribe saldos ni datos de clientes. Las claves del servidor solo se guardan
en el archivo privado ignorado por Git; no se imprimen ni se pasan como argumentos.

En este entorno `db pull` no pudo crear su base de comparación porque no hay
Docker/Podman. Se creó el nombre de migración con la CLI, se copió el SQL probado y
se registró como aplicado mediante `migration repair`. La lista local/remota coincide.

## Seguridad y límites de esta entrega

El navegador solo recibe una cookie opaca `HttpOnly`, `SameSite=Strict` y un token
CSRF. Los JWT y las claves de Supabase permanecen en el servidor. Las sesiones
caducan tras 30 minutos de inactividad u ocho horas como máximo; reiniciar el
servidor las invalida. Los intentos de acceso fallidos se limitan por cuenta y origen.

Las siete tablas están en `operator_private`, con RLS y sin privilegios directos
para visitantes ni usuarios autenticados. La entrada pública es `security invoker`;
delega en una función privada que comprueba `auth.uid()` y el operador activo en
cada operación. No se confía en datos de rol editables por el usuario. La función
privada usa `search_path` vacío y no ejecuta SQL dinámico.

El servidor se limita a loopback. Una publicación necesita HTTPS, cookies seguras,
almacenamiento de documentos duradero y configuración operativa de sesiones y
copias de seguridad. No publicar `public/` como si fuera un portal funcional: las
operaciones necesitan el servidor Node y Supabase.

El asesor de Supabase reportó un aviso de protección contra contraseñas filtradas
deshabilitada. Esa protección requiere un plan Pro o superior; no se cambió el plan.
Las cuentas de esta entrega utilizan claves aleatorias largas, sin contraseñas
elegidas o reutilizadas. Ver [seguridad de contraseñas](https://supabase.com/docs/guides/auth/password-security).

Referencias: [Supabase Auth Admin](https://supabase.com/docs/reference/javascript/auth-admin-createuser),
[RLS y privilegios](https://supabase.com/docs/guides/database/postgres/row-level-security)
y [funciones de base de datos](https://supabase.com/docs/guides/database/functions).

## Verificación

```powershell
npm test
```

Las pruebas HTTP verifican sesiones, CSRF, origen, caducidad, bloqueo de archivos
privados, límites de acceso y documentos inválidos. Las pruebas de servicios cubren
centésimas, montos, creación de cuentas y reversión de altas fallidas.

`database/verify.sql` comprueba permisos y reglas de negocio en una transacción
que termina con `ROLLBACK`: estudiante pendiente, aprobación con documentos,
renovación, identidad, límites, bloqueo, idempotencia, referencias y revocación.

En la revisión funcional se probaron las operaciones contra Supabase con datos
ficticios. Los artefactos de revisión visual se guardan en `output/playwright/`,
ignorado por Git. El proyecto exige además `flutter analyze` y `flutter test`
antes del commit, aunque la app móvil no haya cambiado.
