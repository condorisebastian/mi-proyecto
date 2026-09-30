// Script de utilidad: asigna el PIN unico de 4 digitos a los documentos de
// prueba en Cloud Firestore (colecciones `usuarios` y `conductores`).
//
// El login de la app ya no usa Firebase Auth ni contrasena: cada pasajero y
// conductor se identifica por su PIN. Este script siembra esos PIN en los
// documentos existentes (no los crea).
//
// Uso:
//   SET GOOGLE_APPLICATION_CREDENTIALS=C:\ruta\a\service-account.json
//   node tools/firebase/seed_pins.js
//
// La cuenta de servicio es un secreto: NUNCA versionarla.

const path = require('path');

let admin;
try {
  admin = {
    app: require('firebase-admin/app'),
    firestore: require('firebase-admin/firestore'),
  };
} catch (e) {
  console.error('Requerido: npm install firebase-admin en este directorio');
  process.exit(1);
}

const { initializeApp, cert } = admin.app;
const { getFirestore } = admin.firestore;

const serviceAccountPath =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, 'service-account.json');

initializeApp({
  credential: cert(require(serviceAccountPath)),
  projectId: 'transita-bolivia',
});

const db = getFirestore();

// documento -> PIN unico. Los pasajeros van en `usuarios`; los conductores en
// `conductores` (su usuario vinculado NO lleva pin).
const PINS = {
  'u-1': '0000', // admin
  'u-2': '1234', // Sebastian (estudiante)
  'u-3': '2345', // Maria (civil)
  'u-4': '3456', // Pedro (adulto mayor)
  'u-5': '4567', // Ana (civil)
  'c-1': '5678', // Juan (conductor)
  'c-2': '6789', // Carlos (conductor)
};

async function main() {
  for (const [docId, pin] of Object.entries(PINS)) {
    const collection = docId.startsWith('c-') ? 'conductores' : 'usuarios';
    const ref = db.collection(collection).doc(docId);
    const snap = await ref.get();
    if (!snap.exists) {
      console.warn(`OMITE   ${collection}/${docId} (no existe)`);
      continue;
    }
    await ref.update({ pin });
    console.log(`PIN OK  ${collection}/${docId} = ${pin}`);
  }
}

main().catch((e) => { console.error('FATAL', e); process.exit(1); });
