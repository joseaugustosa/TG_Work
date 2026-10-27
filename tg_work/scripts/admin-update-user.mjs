/**
 * Atualiza email/password/nome de um utilizador Auth (Admin SDK).
 * Uso (ADC): node scripts/admin-update-user.mjs --uid=UID --email=a@b.c --password=secret --name="Nome"
 */
import { initializeApp, applicationDefault, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';

const projectId = 'tg-work-2026';

function arg(name) {
  const prefix = `--${name}=`;
  const hit = process.argv.find((a) => a.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : '';
}

function initAdmin() {
  try {
    initializeApp({ credential: applicationDefault(), projectId });
    return;
  } catch (_) {}
  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (keyPath && existsSync(keyPath)) {
    initializeApp({
      credential: cert(JSON.parse(readFileSync(keyPath, 'utf8'))),
      projectId,
    });
    return;
  }
  throw new Error(
    'Sem credenciais admin. Corre: gcloud auth application-default login'
  );
}

const uid = arg('uid').trim();
const email = arg('email').trim().toLowerCase();
const password = arg('password');
const name = arg('name');
const role = arg('role').trim();

if (!uid) {
  console.error('Falta --uid=');
  process.exit(1);
}

initAdmin();
const auth = getAuth();
const db = getFirestore();

const authUpdate = {};
if (email) authUpdate.email = email;
if (password) authUpdate.password = password;
if (name !== '') authUpdate.displayName = name;

if (Object.keys(authUpdate).length > 0) {
  await auth.updateUser(uid, authUpdate);
}

const fsUpdate = {};
if (email) fsUpdate.email = email;
if (name !== '') fsUpdate.displayName = name;
if (role === 'admin' || role === 'user') fsUpdate.role = role;
if (Object.keys(fsUpdate).length > 0) {
  await db.collection('app_users').doc(uid).set(fsUpdate, { merge: true });
}

console.log(JSON.stringify({ ok: true, uid }));
