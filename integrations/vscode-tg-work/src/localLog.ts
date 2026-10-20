import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

/** Onde ficam sessões apenas no PC (JSON Lines — uma sessão por linha). */
export function localIdeSessionsFilePath(): string {
  let base: string;
  if (process.platform === 'win32') {
    const la = process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local');
    base = path.join(la, 'TG Work');
  } else {
    base = path.join(os.homedir(), '.tg-work');
  }
  const dir = path.join(base, 'ide-sessions');
  return path.join(dir, 'sessions.jsonl');
}

// ──────────────────────────────────────────────────────────────────────────────
// Sessão em curso: ficheiro local por sessão (um por janela/workspace)
// ──────────────────────────────────────────────────────────────────────────────

export interface InProgressSession {
  sessionId: string;
  openedAtMs: number;
  lastHeartbeatMs: number;
  countingLabel: string;
  countingFolderFsPath: string;
  workspaceFileFsPath: string;
  workspaceWindowTitle: string;
  tgProjectId: string;
  editor: string;
}

function ideSessionsDir(): string {
  const fp = localIdeSessionsFilePath();
  return path.dirname(fp);
}

function inProgressFilePath(sessionId: string): string {
  return path.join(ideSessionsDir(), `in-progress-${sessionId}.json`);
}

/** Cria ou actualiza o ficheiro de sessão em curso (sem rede). */
export function saveInProgressSession(sess: InProgressSession): void {
  const dir = ideSessionsDir();
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(inProgressFilePath(sess.sessionId), JSON.stringify(sess), 'utf8');
}

/** Remove o ficheiro de sessão em curso (chamado depois de gravar sessão fechada). */
export function clearInProgressSession(sessionId: string): void {
  try {
    fs.unlinkSync(inProgressFilePath(sessionId));
  } catch {
    // já não existe — ok
  }
}

/** Lê todos os ficheiros `in-progress-*.json` deixados por sessões que não fecharam a tempo. */
export function readAllPendingInProgress(): InProgressSession[] {
  const dir = ideSessionsDir();
  let entries: string[];
  try {
    entries = fs.readdirSync(dir);
  } catch {
    return [];
  }
  const result: InProgressSession[] = [];
  for (const name of entries) {
    if (!name.startsWith('in-progress-') || !name.endsWith('.json')) {
      continue;
    }
    try {
      const txt = fs.readFileSync(path.join(dir, name), 'utf8');
      const obj = JSON.parse(txt) as InProgressSession;
      if (obj.sessionId && obj.openedAtMs) {
        result.push(obj);
      }
    } catch {
      // ficheiro corrompido — ignora
    }
  }
  return result;
}

// ──────────────────────────────────────────────────────────────────────────────
// Sessão à espera de confirmação (Sim/Não) na próxima abertura do IDE
// ──────────────────────────────────────────────────────────────────────────────

export interface PendingConfirmSession {
  sessionId: string;
  openedAtMs: number;
  closedAtMs: number;
  durationSeconds: number;
  countingLabel: string;
  countingFolderFsPath: string;
  workspaceFileFsPath: string;
  workspaceWindowTitle: string;
  tgProjectId: string;
  editor: string;
  /** Motivo do fecho (fecho-janela, sigterm, recuperação, …). */
  reason: string;
}

function pendingConfirmFilePath(sessionId: string): string {
  return path.join(ideSessionsDir(), `pending-confirm-${sessionId}.json`);
}

/** Guarda sessão fechada à espera de Sim/Não na próxima abertura. */
export function savePendingConfirmSession(sess: PendingConfirmSession): void {
  const dir = ideSessionsDir();
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(pendingConfirmFilePath(sess.sessionId), JSON.stringify(sess), 'utf8');
}

export function clearPendingConfirmSession(sessionId: string): void {
  try {
    fs.unlinkSync(pendingConfirmFilePath(sessionId));
  } catch {
    //
  }
}

export function readAllPendingConfirm(): PendingConfirmSession[] {
  const dir = ideSessionsDir();
  let entries: string[];
  try {
    entries = fs.readdirSync(dir);
  } catch {
    return [];
  }
  const result: PendingConfirmSession[] = [];
  for (const name of entries) {
    if (!name.startsWith('pending-confirm-') || !name.endsWith('.json')) {
      continue;
    }
    try {
      const txt = fs.readFileSync(path.join(dir, name), 'utf8');
      const obj = JSON.parse(txt) as PendingConfirmSession;
      if (obj.sessionId && obj.openedAtMs && obj.closedAtMs && obj.durationSeconds >= 0) {
        result.push(obj);
      }
    } catch {
      //
    }
  }
  result.sort((a, b) => b.closedAtMs - a.closedAtMs);
  return result;
}

/** Grava sempre no disco (modo apenas PC — sem conta Firebase necessária). */
export function appendIdeSessionLocally(entry: Record<string, unknown>): string {
  const filePath = localIdeSessionsFilePath();
  const dir = path.dirname(filePath);
  fs.mkdirSync(dir, { recursive: true });
  const line = `${JSON.stringify(entry)}\n`;
  fs.appendFileSync(filePath, line, 'utf8');
  return filePath;
}

/** Formato curto para segundos (ex.: `2h 15m`, `45m 3s`). */
export function formatDurationHumanPt(totalSeconds: number): string {
  const s = Math.max(0, Math.floor(totalSeconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  if (h > 0) {
    return m > 0 ? `${h}h ${m}m` : `${h}h`;
  }
  if (m > 0) {
    return `${m}m ${sec}s`;
  }
  return `${sec}s`;
}

export interface IdeSessionTotalsRow {
  /** Chave estável para agrupar (ID TG ou pasta+nome). */
  aggregateKey: string;
  tgProjectId: string;
  workspaceName: string;
  workspaceRoot: string;
  sessionCount: number;
  /** Dias de calendário locais com pelo menos uma sessão gravada neste grupo. */
  distinctLocalDays: number;
  totalSeconds: number;
}

function localYyyyMmDdFromIso(openedAt: string): string {
  const ms = Date.parse(openedAt.trim());
  if (Number.isNaN(ms)) {
    return '';
  }
  const d = new Date(ms);
  const y = d.getFullYear();
  const mo = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${mo}-${day}`;
}

function resolveWorkDateLocal(entry: Record<string, unknown>): string {
  const w = typeof entry.workDateLocal === 'string' ? entry.workDateLocal.trim() : '';
  if (/^\d{4}-\d{2}-\d{2}$/.test(w)) {
    return w;
  }
  const opened =
    typeof entry.openedAt === 'string'
      ? entry.openedAt
      : typeof entry.recordedAt === 'string'
        ? entry.recordedAt
        : '';
  return localYyyyMmDdFromIso(opened);
}

/**
 * Lê `sessions.jsonl` e soma `durationSeconds` por projeto.
 * Só inclui sessões já **fechadas** e gravadas no ficheiro (a sessão actual na IDE ainda não conta).
 */
export function summarizeLocalIdeSessions(
  filePath: string = localIdeSessionsFilePath()
): {
  rows: IdeSessionTotalsRow[];
  grandTotalSeconds: number;
  grandTotalSessions: number;
  grandDistinctLocalDays: number;
  parseErrors: number;
} {
  const grandTotalSeconds = { v: 0 };
  const grandTotalSessions = { v: 0 };
  const parseErrors = { v: 0 };
  const grandDayKeys = new Set<string>();

  const map = new Map<
    string,
    {
      tgProjectId: string;
      workspaceName: string;
      workspaceRoot: string;
      sessionCount: number;
      totalSeconds: number;
      /** yyyy-mm-dd locais por sessão */
      distinctDays: Set<string>;
    }
  >();

  let raw = '';
  try {
    raw = fs.readFileSync(filePath, 'utf8');
  } catch {
    return {
      rows: [],
      grandTotalSeconds: 0,
      grandTotalSessions: 0,
      grandDistinctLocalDays: 0,
      parseErrors: 0,
    };
  }

  const lines = raw.split(/\r?\n/);
  for (const line of lines) {
    const t = line.trim();
    if (!t.length) {
      continue;
    }
    try {
      const obj = JSON.parse(t) as Record<string, unknown>;
      const durationSeconds =
        typeof obj.durationSeconds === 'number' ? Math.max(0, Math.floor(obj.durationSeconds)) : 0;
      const tgProjectId =
        typeof obj.tgProjectId === 'string' ? obj.tgProjectId.trim() : '';
      const workspaceName =
        typeof obj.workspaceName === 'string' ? obj.workspaceName.trim() : '';
      const workspaceRoot =
        typeof obj.workspaceRoot === 'string' ? obj.workspaceRoot.trim() : '';
      const aggregateKey =
        tgProjectId.length > 0
          ? `tg:${tgProjectId}`
          : `ws:${workspaceRoot}|${workspaceName}`;

      const dayKey = resolveWorkDateLocal(obj);
      if (dayKey.length) {
        grandDayKeys.add(dayKey);
      }

      grandTotalSessions.v += 1;
      grandTotalSeconds.v += durationSeconds;

      const prev = map.get(aggregateKey);
      if (prev) {
        prev.sessionCount += 1;
        prev.totalSeconds += durationSeconds;
        if (dayKey.length) {
          prev.distinctDays.add(dayKey);
        }
        if (!prev.workspaceName && workspaceName) {
          prev.workspaceName = workspaceName;
        }
        if (!prev.workspaceRoot && workspaceRoot) {
          prev.workspaceRoot = workspaceRoot;
        }
      } else {
        const distinctDays = new Set<string>();
        if (dayKey.length) {
          distinctDays.add(dayKey);
        }
        map.set(aggregateKey, {
          tgProjectId,
          workspaceName,
          workspaceRoot,
          sessionCount: 1,
          totalSeconds: durationSeconds,
          distinctDays,
        });
      }
    } catch {
      parseErrors.v += 1;
    }
  }

  const rows: IdeSessionTotalsRow[] = [...map.entries()].map(([aggregateKey, v]) => ({
    aggregateKey,
    tgProjectId: v.tgProjectId,
    workspaceName: v.workspaceName,
    workspaceRoot: v.workspaceRoot,
    sessionCount: v.sessionCount,
    distinctLocalDays: v.distinctDays.size,
    totalSeconds: v.totalSeconds,
  }));
  rows.sort((a, b) => b.totalSeconds - a.totalSeconds);

  return {
    rows,
    grandTotalSeconds: grandTotalSeconds.v,
    grandTotalSessions: grandTotalSessions.v,
    grandDistinctLocalDays: grandDayKeys.size,
    parseErrors: parseErrors.v,
  };
}
