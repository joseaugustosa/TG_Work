const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

function assertAdmin(callerData) {
  const c = callerData || {};
  if (c.role !== 'admin' || c.blocked === true || c.deleted === true) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Só administradores podem alterar utilizadores.'
    );
  }
}

/**
 * Atualiza email / palavra-passe / nome / role na Auth + app_users.
 * Só invocável por admin ativo.
 */
exports.adminUpdateUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sem sessão.');
  }

  const callerSnap = await admin
    .firestore()
    .collection('app_users')
    .doc(context.auth.uid)
    .get();
  assertAdmin(callerSnap.data());

  const uid = String(data?.uid || '').trim();
  if (!uid) {
    throw new functions.https.HttpsError('invalid-argument', 'uid em falta.');
  }

  const authUpdate = {};
  if (typeof data.email === 'string' && data.email.trim()) {
    authUpdate.email = data.email.trim().toLowerCase();
  }
  if (typeof data.password === 'string' && data.password.length > 0) {
    if (data.password.length < 6) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'A palavra-passe precisa de pelo menos 6 caracteres.'
      );
    }
    authUpdate.password = data.password;
  }
  if (typeof data.displayName === 'string') {
    authUpdate.displayName = data.displayName.trim();
  }

  if (Object.keys(authUpdate).length > 0) {
    try {
      await admin.auth().updateUser(uid, authUpdate);
    } catch (e) {
      const code = e?.code || '';
      const msg = e?.message || String(e);
      if (code === 'auth/email-already-exists') {
        throw new functions.https.HttpsError(
          'already-exists',
          'Esse email já está em uso.'
        );
      }
      if (code === 'auth/user-not-found') {
        throw new functions.https.HttpsError(
          'not-found',
          'Utilizador Auth não encontrado (só existe no Firestore?).'
        );
      }
      throw new functions.https.HttpsError('internal', msg);
    }
  }

  const fsUpdate = {};
  if (authUpdate.email) fsUpdate.email = authUpdate.email;
  if (typeof data.displayName === 'string') {
    fsUpdate.displayName = data.displayName.trim();
  }
  if (data.role === 'admin' || data.role === 'user') {
    fsUpdate.role = data.role;
  }
  if (typeof data.blocked === 'boolean') {
    fsUpdate.blocked = data.blocked;
  }
  if (Object.keys(fsUpdate).length > 0) {
    await admin
      .firestore()
      .collection('app_users')
      .doc(uid)
      .set(fsUpdate, { merge: true });
    if (fsUpdate.role === 'admin') {
      await admin
        .firestore()
        .collection('app_config')
        .doc('access')
        .set({ hasAdmin: true }, { merge: true });
    }
  }

  return { ok: true };
});
