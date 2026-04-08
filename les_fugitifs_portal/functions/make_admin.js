const admin = require('firebase-admin');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function makeAdmin() {
  const email = 'pierreyves.franzetti@gmail.com';
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, { admin: true });
  console.log(`Admin ajouté pour ${email}`);
  process.exit(0);
}

makeAdmin().catch((error) => {
  console.error(error);
  process.exit(1);
});