// Script de utilidad: crea los usuarios de prueba en Firebase Authentication.
// Requisito previo: tener habilitado el proveedor Email/Password en la consola
// de Firebase (Build > Authentication > Empezar > Sign-in method).
//
// Uso:
//   SET GOOGLE_APPLICATION_CREDENTIALS=C:\ruta\a\service-account.json
//   node tools/firebase/create_auth_users.js
//
// La cuenta de servicio es un secreto: NUNCA versionarla.

const path = require('path');

let init;
try {
  const { initializeApp, cert } = require('firebase-admin/app');
  const { getAuth } = require('firebase-admin/auth');
  init = { initializeApp, cert, getAuth };
} catch (e) {
  console.error('Requerido: npm install firebase-admin en este directorio');
  process.exit(1);
}

const { initializeApp, cert } = init;
const { getAuth } = init;

const serviceAccountPath =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, 'service-account.json');

initializeApp({
  credential: cert(require(serviceAccountPath)),
  projectId: 'transita-bolivia',
});

const auth = getAuth();

// usuarios de prueba: [email, password, role]
const usuarios = [
  ['sebastian@test.com',    '123456', 'PASAJERO'],
  ['maria@test.com',        '123456', 'PASAJERO'],
  ['pedro@test.com',        '123456', 'PASAJERO'],
  ['ana.vargas@test.com',   '123456', 'PASAJERO'],
  ['juan.perez@test.com',   '123456', 'CONDUCTOR'],
  ['carlos.rojas@test.com', '123456', 'CONDUCTOR'],
  ['admin@transporte.com',  '123456', 'ADMIN'],
];

async function main() {
  for (const [email, pass, role] of usuarios) {
    try {
      await auth.getUserByEmail(email);
      console.log(`EXISTE  ${email}`);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        try {
          const rec = await auth.createUser({
            email,
            password: pass,
            emailVerified: false,
            displayName: email.split('@')[0],
          });
          console.log(`CREADO  ${email} (uid=${rec.uid})`);
        } catch (err) {
          console.error(`ERR-CREA ${email}: ${err.message}`);
        }
      } else {
        console.error(`ERR-BUSCA ${email}: ${e.message}`);
      }
    }
  }
}

main().catch((e) => { console.error('FATAL', e); process.exit(1); });
