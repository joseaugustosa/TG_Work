/**
 * Remove project/workspace from IDE agenda (Firestore admin).
 * Usage: node scripts/remove-from-ide-agenda.mjs "Axiom-3D-Wood"
 */
import { initializeApp, applicationDefault, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';

const targetName = process.argv[2]?.trim();
if (!targetName) {
  console.error('Usage: node scripts/remove-from-ide-agenda.mjs "<project or workspace name>"');
  process.exit(1);
}

const projectId = 'tg-work-2026';

function initAdmin() {
  try {
    initializeApp({ credential: applicationDefault(), projectId });
    return;
  } catch (_) {}

  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (keyPath && existsSync(keyPath)) {
    initializeApp({ credential: cert(JSON.parse(readFileSync(keyPath, 'utf8'))), projectId });
    return;
  }

  throw new Error(
    'Sem credenciais admin. Corre: gcloud auth application-default login\n' +
      'ou define GOOGLE_APPLICATION_CREDENTIALS para uma service account.'
  );
}

initAdmin();
const db = getFirestore();

const norm = (s) => s.trim().toLowerCase();

async function main() {
  console.log(`A procurar "${targetName}" no projeto ${projectId}...`);

  const projectSnap = await db.collection('projects').get();
  const matchingProjects = projectSnap.docs.filter(
    (d) => norm(d.data().name ?? '') === norm(targetName)
  );

  const aggregateKeys = new Set([`ws:${targetName.trim()}`]);
  for (const d of matchingProjects) {
    aggregateKeys.add(`tg:${d.id}`);
    console.log(`Projeto TG Work: ${d.data().name} (${d.id})`);
  }

  const logsSnap = await db.collection('user_ide_session_logs').get();
  const logsToDelete = logsSnap.docs.filter((d) => {
    const data = d.data();
    const ws = String(data.workspaceName ?? '');
    const pid = String(data.tgProjectId ?? '');
    if (norm(ws) === norm(targetName)) return true;
    return matchingProjects.some((p) => p.id === pid);
  });
  console.log(`Sessões IDE a apagar: ${logsToDelete.length}`);

  const usersSnap = await db.collection('user_ide_schedule').get();
  const cardsToDelete = [];
  for (const userDoc of usersSnap.docs) {
    const cardsSnap = await userDoc.ref.collection('cards').get();
    for (const card of cardsSnap.docs) {
      const data = card.data();
      const title = String(data.title ?? '');
      const agg = String(data.aggregateKey ?? '');
      const pid = String(data.tgProjectId ?? '');
      if (norm(title) === norm(targetName)) {
        cardsToDelete.push(card.ref);
        if (agg) aggregateKeys.add(agg);
        continue;
      }
      if (agg && aggregateKeys.has(agg)) {
        cardsToDelete.push(card.ref);
      } else if (pid && matchingProjects.some((p) => p.id === pid)) {
        cardsToDelete.push(card.ref);
        aggregateKeys.add(`tg:${pid}`);
      }
    }
  }
  console.log(`Cartões Kanban a apagar: ${cardsToDelete.length}`);

  const userIds = new Set(logsToDelete.map((d) => String(d.data().userId ?? '')).filter(Boolean));
  for (const userDoc of usersSnap.docs) userIds.add(userDoc.id);

  for (const d of logsToDelete) {
    await d.ref.delete();
  }
  for (const ref of cardsToDelete) {
    await ref.delete();
  }

  for (const uid of userIds) {
    if (!uid) continue;
    await db.collection('user_settings').doc(uid).set(
      {
        ideAgendaExcludedAggregateKeys: FieldValue.arrayUnion(...aggregateKeys),
      },
      { merge: true }
    );
  }

  console.log('Concluído.');
  console.log('Chaves excluídas:', [...aggregateKeys].join(', '));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
