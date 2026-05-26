import * as path from 'path';

import { summarizeIdentityToolkitErrorBody } from './firebaseAuthErrors';

/** Corpo `{ fields: {...} }` para Firestore REST. */
export function ideSessionFirestoreFields(payload: {
  userId: string;
  tgProjectId: string;
  workspaceRoot: string;
  workspaceName: string;
  editor: string;
  openedAtMs: number;
  closedAtMs: number;
  durationSeconds: number;
}) {
  return {
    fields: {
      userId: { stringValue: payload.userId },
      tgProjectId: { stringValue: payload.tgProjectId },
      workspaceRoot: { stringValue: payload.workspaceRoot },
      workspaceName: { stringValue: payload.workspaceName },
      editor: { stringValue: payload.editor },
      openedAt: { timestampValue: new Date(payload.openedAtMs).toISOString() },
      closedAt: { timestampValue: new Date(payload.closedAtMs).toISOString() },
      durationSeconds: { integerValue: String(payload.durationSeconds) },
    },
  };
}

export async function signInWithPassword(
  apiKey: string,
  email: string,
  password: string
): Promise<{ idToken: string; refreshToken: string; localId: string }> {
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(
    apiKey
  )}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email,
      password,
      returnSecureToken: true,
    }),
  });
  const text = await res.text();
  let body: unknown;
  try {
    body = JSON.parse(text) as unknown;
  } catch {
    body = {};
  }

  const j = (typeof body === 'object' && body !== null ? body : {}) as Record<string, unknown>;

  if (!res.ok) {
    throw new Error(summarizeIdentityToolkitErrorBody(j, `${res.status} ${res.statusText}`));
  }
  return {
    idToken: String(j.idToken),
    refreshToken: String(j.refreshToken),
    localId: String(j.localId),
  };
}

/** Cache de acesso: token Firebase válido por 1 h — renovado proactivamente antes de expirar. */
interface AccessTokenCache {
  apiKey: string;
  refreshToken: string;
  idToken: string;
  /** Instante (ms) após o qual o token já não deve ser usado (5 min de margem). */
  expiresAtMs: number;
}

let _accessTokenCache: AccessTokenCache | null = null;

/**
 * Devolve token em cache se ainda válido, caso contrário renova via Firebase.
 * Usar em vez de `refreshIdToken` sempre que possível — reduz 2 chamadas HTTP a 1 no fecho.
 */
export async function refreshIdTokenCached(
  apiKey: string,
  refreshToken: string
): Promise<string> {
  const c = _accessTokenCache;
  if (
    c &&
    c.apiKey === apiKey &&
    c.refreshToken === refreshToken &&
    Date.now() < c.expiresAtMs
  ) {
    return c.idToken;
  }
  const idToken = await refreshIdToken(apiKey, refreshToken);
  _accessTokenCache = {
    apiKey,
    refreshToken,
    idToken,
    expiresAtMs: Date.now() + 55 * 60_000, // 55 min (tokens duram 60 min)
  };
  return idToken;
}

/** Invalida o cache (usar ao fazer signOut ou ao mudar de utilizador). */
export function clearAccessTokenCache(): void {
  _accessTokenCache = null;
}

export async function refreshIdToken(
  apiKey: string,
  refreshToken: string
): Promise<string> {
  const url = `https://securetoken.googleapis.com/v1/token?key=${encodeURIComponent(apiKey)}`;
  const formBody = `grant_type=refresh_token&refresh_token=${encodeURIComponent(refreshToken)}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: formBody,
  });
  const text = await res.text();
  let parsed: unknown;
  try {
    parsed = JSON.parse(text) as unknown;
  } catch {
    parsed = {};
  }

  const j = (typeof parsed === 'object' && parsed !== null ? parsed : {}) as Record<string, unknown>;

  if (!res.ok) {
    throw new Error(summarizeIdentityToolkitErrorBody(j, `${res.status} ${res.statusText}`));
  }
  const idTok = String(j.id_token ?? '');
  if (!idTok) throw new Error('Resposta refresh sem id_token');
  return idTok;
}

function firestoreStringField(fields: Record<string, unknown> | undefined, key: string): string {
  if (!fields) {
    return '';
  }
  const cell = fields[key];
  if (typeof cell !== 'object' || cell === null || !('stringValue' in cell)) {
    return '';
  }
  return String((cell as { stringValue?: string }).stringValue ?? '').trim();
}

function documentNameToFirestoreDocId(fullName: string): string {
  /** .../documents/projects/DOC */
  const i = fullName.lastIndexOf('/');
  return i >= 0 ? fullName.slice(i + 1) : fullName;
}

/**
 * Corre consultas iguais a `projects.ideCountingFolderFsPath` até haver primeiro acerto.
 * Respeita a string gravada pela app TG Work.
 */
export async function firestoreFindFirstProjectMatchingIdeFsPath(opts: {
  firebaseProjectId: string;
  accessToken: string;
  ideFsPathCandidates: readonly string[];
}): Promise<string> {
  const { firebaseProjectId, accessToken, ideFsPathCandidates } = opts;
  const seen = new Set<string>();
  const url = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(
    firebaseProjectId
  )}/databases/(default)/documents:runQuery`;

  for (let raw of ideFsPathCandidates) {
    raw = raw.trim();
    if (!raw) {
      continue;
    }
    if (seen.has(raw)) {
      continue;
    }
    seen.add(raw);

    const body = {
      structuredQuery: {
        from: [{ collectionId: 'projects' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'ideCountingFolderFsPath' },
            op: 'EQUAL',
            value: { stringValue: raw },
          },
        },
        limit: 3,
      },
    };

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    const txt = await res.text();

    if (!res.ok) {
      throw new Error(`Firestore runQuery ${res.status}: ${txt}`);
    }

    let rowsUnknown: unknown;
    try {
      rowsUnknown = JSON.parse(txt);
    } catch {
      continue;
    }
    if (!Array.isArray(rowsUnknown)) {
      continue;
    }

    for (const row of rowsUnknown) {
      if (typeof row !== 'object' || row === null) {
        continue;
      }
      const docWrap = row as { document?: { name?: string } };
      const nm = docWrap.document?.name;
      if (typeof nm !== 'string' || !nm.length) {
        continue;
      }
      return documentNameToFirestoreDocId(nm);
    }
  }

  return '';
}

/** Linha minimalista dos documentos `/projects/{id}` (REST). */
export interface FirestoreProjectBrief {
  id: string;
  name: string;
  ideCountingFolderFsPath: string;
}

let _listedProjectsMemo: {
  firebaseProjectId: string;
  atMs: number;
  rows: FirestoreProjectBrief[];
} | null = null;

const LIST_PROJECTS_CACHE_MS = 90_000;

/**
 * Lista projectos até [pageSize] (sem paginar — suficiente para equipas pequenas).
 */
export async function firestoreListProjectsBrief(opts: {
  firebaseProjectId: string;
  accessToken: string;
  pageSize?: number;
  bustCache?: boolean;
}): Promise<FirestoreProjectBrief[]> {
  const pageSize = opts.pageSize ?? 400;
  const now = Date.now();
  const mem = _listedProjectsMemo;
  if (
    !opts.bustCache &&
    mem &&
    mem.firebaseProjectId === opts.firebaseProjectId &&
    now - mem.atMs < LIST_PROJECTS_CACHE_MS
  ) {
    return mem.rows;
  }

  const url = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(
    opts.firebaseProjectId
  )}/databases/(default)/documents/projects?pageSize=${pageSize}`;
  const res = await fetch(url, {
    method: 'GET',
    headers: { Authorization: `Bearer ${opts.accessToken}` },
  });
  const txt = await res.text();
  if (!res.ok) {
    throw new Error(`Firestore list projects ${res.status}: ${txt}`);
  }
  type ListResp = {
    documents?: Array<{ name?: string; fields?: Record<string, unknown> }>;
  };
  const j = JSON.parse(txt) as ListResp;
  const docs = j.documents ?? [];
  const rows: FirestoreProjectBrief[] = [];
  for (const d of docs) {
    if (!d.name) {
      continue;
    }
    const id = documentNameToFirestoreDocId(d.name);
    rows.push({
      id,
      name: firestoreStringField(d.fields, 'name'),
      ideCountingFolderFsPath: firestoreStringField(d.fields, 'ideCountingFolderFsPath'),
    });
  }
  _listedProjectsMemo = { firebaseProjectId: opts.firebaseProjectId, atMs: now, rows };
  return rows;
}

/** Junta dígitos, letras ignorando espaços, traços e underscore. */
function collapseNameRough(s: string): string {
  return s.trim().replace(/_/g, ' ').replace(/\s+/g, '').replace(/-/g, '').toLowerCase();
}

/**
 * Fallback: apenas se existir um único projecto cuja slug do nome coincide com a slug do basename da pasta de contagem.
 */
export async function firestoreInferProjectIdFromBasenameSlug(opts: {
  firebaseProjectId: string;
  accessToken: string;
  countingFolderFsPath: string;
}): Promise<string> {
  const base = collapseNameRough(path.basename(path.normalize(opts.countingFolderFsPath.trim())));
  if (!base.length) {
    return '';
  }
  const briefs = await firestoreListProjectsBrief({
    firebaseProjectId: opts.firebaseProjectId,
    accessToken: opts.accessToken,
  });
  let hit = '';
  for (const p of briefs) {
    const slug = collapseNameRough(p.name);
    if (!slug.length) {
      continue;
    }
    if (slug === base) {
      if (hit) {
        return '';
      }
      hit = p.id;
    }
  }
  return hit;
}

export async function firestoreCreateSessionLog(opts: {
  projectId: string;
  documentId: string;
  accessToken: string;
  payload: Record<string, unknown>;
}): Promise<void> {
  const { projectId, documentId, accessToken, payload } = opts;
  const base = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(
    projectId
  )}/databases/(default)/documents/user_ide_session_logs`;
  const url = `${base}?documentId=${encodeURIComponent(documentId)}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`Firestore ${res.status}: ${txt}`);
  }
}

/** Actualiza só `closedAt` e `durationSeconds` no doc criado ao abrir o workspace. */
export async function firestorePatchSessionEnd(opts: {
  projectId: string;
  documentId: string;
  accessToken: string;
  closedAtMs: number;
  durationSeconds: number;
}): Promise<void> {
  const { projectId, documentId, accessToken, closedAtMs, durationSeconds } = opts;
  const url =
    `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}` +
    `/databases/(default)/documents/user_ide_session_logs/${encodeURIComponent(documentId)}` +
    `?updateMask.fieldPaths=closedAt&updateMask.fieldPaths=durationSeconds`;

  const body = {
    fields: {
      closedAt: { timestampValue: new Date(closedAtMs).toISOString() },
      durationSeconds: { integerValue: String(durationSeconds) },
    },
  };

  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`Firestore PATCH ${res.status}: ${txt}`);
  }
}
