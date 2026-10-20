import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { randomUUID } from 'crypto';
import {
  clearAccessTokenCache,
  firestoreCreateSessionLog,
  firestoreFindFirstProjectMatchingIdeFsPath,
  firestoreInferProjectIdFromBasenameSlug,
  ideSessionFirestoreFields,
  refreshIdToken,
  refreshIdTokenCached,
  signInWithPassword,
} from './firebaseRest';
import {
  appendIdeSessionLocally,
  clearInProgressSession,
  clearPendingConfirmSession,
  formatDurationHumanPt,
  InProgressSession,
  localIdeSessionsFilePath,
  PendingConfirmSession,
  readAllPendingConfirm,
  readAllPendingInProgress,
  saveInProgressSession,
  savePendingConfirmSession,
  summarizeLocalIdeSessions,
} from './localLog';

const SECRET_REFRESH = 'tgWorkIde.refresh_token';
const SECRET_UID = 'tgWorkIde.local_id';

/** Ver → Saída → «TG Work IDE» — histórico de gravações PC/Firestore. */
let tgIdeLogChannel: vscode.OutputChannel | undefined;

function tgIdeLog(line: string): void {
  tgIdeLogChannel?.appendLine(`[${new Date().toISOString()}] ${line}`);
}

/** Relógio na barra de estado — sessão actual (ainda não está no JSONL até fechar). */
let sessionStatusBar: vscode.StatusBarItem | undefined;
let sessionStatusInterval: ReturnType<typeof setInterval> | undefined;

function disposeSessionStatusTicker(): void {
  if (sessionStatusInterval !== undefined) {
    clearInterval(sessionStatusInterval);
    sessionStatusInterval = undefined;
  }
}

function ensureSessionStatusBar(context: vscode.ExtensionContext): vscode.StatusBarItem {
  if (!sessionStatusBar) {
    sessionStatusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 101);
    sessionStatusBar.command = 'tgWorkIde.flushSession';
    context.subscriptions.push(sessionStatusBar);
  }
  return sessionStatusBar;
}

function refreshSessionStatusUi(context: vscode.ExtensionContext): void {
  const sb = ensureSessionStatusBar(context);
  const sess = current;
  if (!sess) {
    sb.hide();
    disposeSessionStatusTicker();
    return;
  }
  const sec = Math.max(0, Math.floor((Date.now() - sess.openedAtMs) / 1000));
  sb.text = `$(cloud-upload) TG Work · ${sess.countingLabel} · ${formatDurationHumanPt(sec)}`;
  sb.tooltip =
    `Projeto: ${sess.countingLabel}\nTempo desde abertura: ${formatDurationHumanPt(sec)}\n\n` +
    `Clique → Gravar sessão agora (PC + Firestore) e recomeçar.\n` +
    `Ao fechar o IDE: na próxima abertura pergunta Sim/Não para registar.`;
  sb.show();
  if (sessionStatusInterval === undefined) {
    sessionStatusInterval = setInterval(
      () => refreshSessionStatusUi(context),
      15_000
    );
  }
}

function appendSessionTotalsToLog(): void {
  const fp = localIdeSessionsFilePath();
  const { rows, grandTotalSeconds, grandTotalSessions, grandDistinctLocalDays, parseErrors } =
    summarizeLocalIdeSessions(fp);
  tgIdeLog('');
  tgIdeLog('────────── Por projeto: tempo + nº de sessões + dias com sessão (PC) ──────────');
  tgIdeLog(`Ficheiro: ${fp}`);
  if (!grandTotalSessions) {
    tgIdeLog('(Ainda não há linhas em sessions.jsonl — fecha o workspace ou usa «gravar sessão agora».)');
    tgIdeLog('────────────────────────────────────────────────────────────────────');
    return;
  }
  for (const r of rows) {
    const idPart = r.tgProjectId ? r.tgProjectId : '(sem ID TG — pasta/nome)';
    tgIdeLog(
      `· ${formatDurationHumanPt(r.totalSeconds)}  (${r.sessionCount} sess. · ${r.distinctLocalDays} dias)  ${r.workspaceName || '?'}  [${idPart}]`
    );
    if (r.workspaceRoot) {
      tgIdeLog(`    pasta: ${r.workspaceRoot}`);
    }
  }
  tgIdeLog(
    `TOTAL GERAL: ${grandTotalSessions} sessões · ${grandDistinctLocalDays} dias distintos · ${formatDurationHumanPt(grandTotalSeconds)} (${grandTotalSeconds}s)`
  );
  if (parseErrors > 0) {
    tgIdeLog(`Aviso: ${parseErrors} linha(s) ignoradas (JSON inválido).`);
  }
  tgIdeLog('────────────────────────────────────────────────────────────────────');
}

/** Evita repetir a mesma linha quando o workspace oscila durante o arranque. */
let lastIdeSkipLog = '';

/** Persiste a pasta escolhida para contagem nesta janela de workspace. */
const WS_KEY_COUNTING_FOLDER = 'tgWorkIde.countingFolderFsPath.v1';

function explainWhyIdeSessionSkipped(context: vscode.ExtensionContext): string {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders?.length) {
    return 'sem pastas no workspace.';
  }
  const counting = resolveCountingFolderFsPath(context);
  if (!counting) {
    return 'não foi possível resolver a pasta de contagem.';
  }
  if (onlyShortcutWorkspaceSetting()) {
    const wf = vscode.workspace.workspaceFile;
    const wfPath = wf?.scheme === 'file' ? wf.fsPath : '';
    if (!wfPath || !isWorkspaceShortcutFsPath(wfPath)) {
      return `tgWorkIde.onlyShortcutWorkspace=true mas não há atalho *.code-workspace nesta janela (workspaceFile: ${wfPath || 'vazio'}). Abre um .code-workspace ou define onlyShortcutWorkspace=false.`;
    }
  }
  return 'motivo desconhecido (reporta ao TG Work).';
}

function logIdeSessionSkippedOnce(context: vscode.ExtensionContext): void {
  const line = `Sessão IDE não iniciada: ${explainWhyIdeSessionSkipped(context)}`;
  if (line === lastIdeSkipLog) {
    return;
  }
  lastIdeSkipLog = line;
  tgIdeLog(line);
}

interface WindowSession {
  /** UUID único desta sessão — nome do ficheiro local in-progress. */
  sessionId: string;
  /** Inclui pasta de contagem — muda se escolheres outra raiz. */
  identityKey: string;
  workspaceFileFsPath?: string;
  /** Nome da pasta raiz escolhida (ou VS Code folder name). */
  countingLabel: string;
  /** Pasta onde lemos `.tgwork` e onde reportamos `workspaceRoot`. */
  countingFolderFsPath: string;
  /** Nome do workspace na janela (título VS Code/Cursor). */
  workspaceWindowTitle: string;
  tgProjectId: string;
  openedAtMs: number;
}

let extensionContext: vscode.ExtensionContext | undefined;
let current: WindowSession | undefined;
let hostLifecycleHooksInstalled = false;
let heartbeatTimer: ReturnType<typeof setInterval> | undefined;
/** Renova o token proactivamente para que o fecho tenha apenas 1 chamada HTTP. */
let tokenRefreshTimer: ReturnType<typeof setInterval> | undefined;
/** Evita dois finalize em paralelo (deactivate + sigterm ou comando manual). */
let finalizeMutex: Promise<void> = Promise.resolve();

function enqueueFinalize(task: () => Promise<void>): Promise<void> {
  const next = finalizeMutex.then(task, task);
  finalizeMutex = next.catch(() => undefined);
  return next;
}

/**
 * Converte ficheiros in-progress (crash / kill) em pedidos Sim/Não,
 * e mostra a notificação para cada sessão pendente de confirmação.
 */
async function recoverAndPromptPendingOnActivate(
  context: vscode.ExtensionContext
): Promise<void> {
  const minSec = cfg().get<number>('minSessionSeconds') ?? 30;
  const now = Date.now();

  for (const p of readAllPendingInProgress()) {
    const closedAtMs = Math.max(p.lastHeartbeatMs, p.openedAtMs + 1000);
    const durationSeconds = Math.max(0, Math.floor((closedAtMs - p.openedAtMs) / 1000));
    const ageDays = (now - p.openedAtMs) / 86400_000;

    if (ageDays > 45 || durationSeconds < minSec) {
      clearInProgressSession(p.sessionId);
      tgIdeLog(
        `Recuperação: omitida · "${p.countingLabel}" · ${durationSeconds}s` +
          (ageDays > 45 ? ' (>45 dias)' : ` (< mínimo ${minSec}s)`)
      );
      continue;
    }

    try {
      savePendingConfirmSession({
        sessionId: p.sessionId,
        openedAtMs: p.openedAtMs,
        closedAtMs,
        durationSeconds,
        countingLabel: p.countingLabel,
        countingFolderFsPath: p.countingFolderFsPath,
        workspaceFileFsPath: p.workspaceFileFsPath,
        workspaceWindowTitle: p.workspaceWindowTitle,
        tgProjectId: p.tgProjectId,
        editor: p.editor,
        reason: 'recuperacao-crash',
      });
      clearInProgressSession(p.sessionId);
      tgIdeLog(
        `Recuperação: sessão à espera de confirmação · "${p.countingLabel}" · ${durationSeconds}s`
      );
    } catch (e) {
      tgIdeLog(
        `Recuperação: falhou ao guardar pendente (${p.countingLabel}): ${
          e instanceof Error ? e.message : String(e)
        }`
      );
    }
  }

  await promptPendingConfirmSessions(context);
}

/** Pergunta Sim/Não para cada sessão pendente (fecho anterior ou crash). */
async function promptPendingConfirmSessions(
  context: vscode.ExtensionContext
): Promise<void> {
  const pending = readAllPendingConfirm();
  if (!pending.length) {
    return;
  }

  for (const p of pending) {
    const dur = formatDurationHumanPt(p.durationSeconds);
    const pick = await vscode.window.showInformationMessage(
      `TG Work: sessão anterior «${p.countingLabel}» · ${dur}. Registar?`,
      { modal: false },
      'Sim',
      'Não'
    );

    if (pick === 'Sim') {
      try {
        await registerCompletedSession(context, p, true);
        tgIdeLog(
          `Confirmação: SIM · "${p.countingLabel}" · ${p.durationSeconds}s`
        );
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        tgIdeLog(`Confirmação: falha ao registar: ${msg}`);
        void vscode.window.showWarningMessage(`TG Work: falha ao registar: ${msg}`);
        // Mantém o ficheiro pendente para tentar na próxima abertura
        continue;
      }
    } else {
      tgIdeLog(
        `Confirmação: NÃO (descartada) · "${p.countingLabel}" · ${p.durationSeconds}s`
      );
    }
    clearPendingConfirmSession(p.sessionId);
  }
}

function shouldDeferConfirm(reason: string): boolean {
  const r = reason.toLowerCase();
  return r.includes('fecho') || r.includes('sigterm');
}

/** Grava no PC (+ Firestore opcional) uma sessão já fechada e confirmada. */
async function registerCompletedSession(
  context: vscode.ExtensionContext | undefined,
  sess: {
    openedAtMs: number;
    closedAtMs: number;
    durationSeconds: number;
    countingLabel: string;
    countingFolderFsPath: string;
    workspaceFileFsPath: string;
    workspaceWindowTitle: string;
    tgProjectId: string;
    editor: string;
  },
  notify: boolean
): Promise<{ localPath: string; cloudOk: boolean }> {
  const openedIso = new Date(sess.openedAtMs).toISOString();
  const closedIso = new Date(sess.closedAtMs).toISOString();
  const workDateLocal = yyyyMmDdLocal(sess.openedAtMs);
  let localPath = '';
  let cloudOk = false;

  try {
    localPath = appendIdeSessionLocally({
      recordedAt: closedIso,
      workDateLocal,
      openedAt: openedIso,
      closedAt: closedIso,
      durationSeconds: sess.durationSeconds,
      workspaceShortcut: sess.workspaceFileFsPath ?? '',
      workspaceMode: sess.workspaceFileFsPath ? 'code-workspace' : 'folder',
      workspaceRoot: sess.countingFolderFsPath,
      workspaceName: sess.countingLabel,
      workspaceWindowTitle: sess.workspaceWindowTitle,
      countingFolderFsPath: sess.countingFolderFsPath,
      tgProjectId: sess.tgProjectId || '',
      editor: sess.editor,
      countingMode: 'window-open-to-close',
    });
    tgIdeLog(
      `PC: gravado · ${sess.countingLabel} · ${sess.durationSeconds}s · dia=${workDateLocal} · ${path.basename(localPath)}`
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    tgIdeLog(`PC: falha ao gravar: ${msg}`);
    if (notify) {
      void vscode.window.showErrorMessage(`TG Work IDE: falha ao gravar no PC: ${msg}`);
    }
    throw e;
  }

  const syncCloud = cfg().get<boolean>('syncToFirestore') === true;
  if (syncCloud && context) {
    const uid = await context.secrets.get(SECRET_UID);
    const refreshTok = await context.secrets.get(SECRET_REFRESH);
    const apiKey = cfg().get<string>('firebaseApiKey') ?? '';
    const projectId = cfg().get<string>('firebaseProjectId') ?? 'tg-work-2026';
    if (uid && refreshTok && apiKey) {
      try {
        const access = await refreshIdTokenCached(apiKey, refreshTok);
        const docId = randomUUID();
        const body = ideSessionFirestoreFields({
          userId: uid,
          tgProjectId: sess.tgProjectId || '',
          workspaceRoot: sess.countingFolderFsPath,
          workspaceName: sess.countingLabel,
          editor: sess.editor,
          openedAtMs: sess.openedAtMs,
          closedAtMs: sess.closedAtMs,
          durationSeconds: sess.durationSeconds,
        });
        await firestoreCreateSessionLog({
          projectId,
          documentId: docId,
          accessToken: access,
          payload: body,
        });
        cloudOk = true;
        tgIdeLog(
          `Firestore: gravado · ${sess.countingLabel} · ${sess.durationSeconds}s · dia=${workDateLocal} · doc=${docId}`
        );
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        tgIdeLog(`Firestore FALHOU: ${msg}`);
        if (notify) {
          void vscode.window.showWarningMessage(`TG Work: Firestore: ${msg}`);
        }
      }
    } else {
      tgIdeLog(
        'Firestore: sem login — usa «TG Work IDE: iniciar sessão Firebase». Sessão gravada só no PC.'
      );
      if (notify) {
        void vscode.window.showWarningMessage(
          'TG Work: sem login Firebase — sessão só no PC.'
        );
      }
    }
  }

  return { localPath, cloudOk };
}

function normPathKey(fsPath: string): string {
  const n = path.normalize(fsPath);
  return process.platform === 'win32' ? n.toLowerCase() : n;
}

function detectEditor(): string {
  const n = vscode.env.appName.toLowerCase();
  if (n.includes('cursor')) {
    return 'cursor';
  }
  if (n.includes('insiders')) {
    return 'vscode_insiders';
  }
  return 'vscode';
}

function cfg(): vscode.WorkspaceConfiguration {
  return vscode.workspace.getConfiguration('tgWorkIde');
}

/** Atalho multi‑root: `*.code-workspace` ou `*.cursor-workspace`. */
function isWorkspaceShortcutFsPath(fsPath: string): boolean {
  const lower = fsPath.trim().toLowerCase();
  return lower.endsWith('.code-workspace') || lower.endsWith('.cursor-workspace');
}

/**
 * Modo restrito: só conta quando há `*.code-workspace` / `*.cursor-workspace`.
 * Tem de estar explicitamente **true** nas settings — não usar `!== false` porque o defeito do manifest já conta como valor real.
 */
function onlyShortcutWorkspaceSetting(): boolean {
  return cfg().get<boolean>('onlyShortcutWorkspace') === true;
}

function yyyyMmDdLocal(epochMs: number): string {
  const d = new Date(epochMs);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function readProjectJsonLinkSync(folderRootContainingTgWork: string): Record<string, unknown> {
  try {
    const p = path.join(folderRootContainingTgWork, '.tgwork', 'project.json');
    const txt = fs.readFileSync(p, 'utf8');
    return JSON.parse(txt) as Record<string, unknown>;
  } catch {
    return {};
  }
}

async function loadTgLinkAtProjectRoot(folderRootContainingTgWork: string): Promise<Record<string, unknown>> {
  return readProjectJsonLinkSync(folderRootContainingTgWork);
}

function linkedProjectId(link: Record<string, unknown>): string {
  const a = link.tgWorkProjectId ?? link.projectId;
  return typeof a === 'string' ? a : '';
}

let tgFirestoreResolveMemo: { key: string; id: string; atMs: number } | undefined;
const TG_FS_RESOLVE_TTL_MS = 120_000;

function uniqPathCandidates(paths: Iterable<string>): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const raw of paths) {
    const t = raw.trim();
    if (!t) {
      continue;
    }
    const k = normPathKey(path.normalize(t));
    if (seen.has(k)) {
      continue;
    }
    seen.add(k);
    out.push(path.normalize(t));
  }
  return out;
}

/**
 * Possíveis strings que a app gravou em `projects.ideCountingFolderFsPath`
 * para consulta igual no Firestore.
 */
function buildIdeFsPathCandidatesForFirestore(
  countingFolderFsPath: string,
  workspaceFileFsPath?: string
): string[] {
  const acc: string[] = [];

  function variantsOf(fsPathNorm: string): string[] {
    const n = path.normalize(fsPathNorm.trim());
    if (!n) {
      return [];
    }
    if (process.platform !== 'win32') {
      return [n];
    }
    const variants = new Set<string>([n]);
    const m = /^([A-Za-z])(:.*)$/.exec(n);
    if (m?.[2]) {
      variants.add(`${m[1].toUpperCase()}${m[2]}`);
      variants.add(`${m[1].toLowerCase()}${m[2]}`);
    }
    return [...variants];
  }

  for (const v of variantsOf(countingFolderFsPath)) {
    acc.push(v);
  }

  const wsFull = workspaceFileFsPath?.trim();
  if (wsFull?.length && isWorkspaceShortcutFsPath(wsFull)) {
    for (const v of variantsOf(wsFull)) {
      acc.push(v);
    }
  }

  return uniqPathCandidates(acc);
}

async function resolveTgProjectFromFirestoreBestEffort(
  context: vscode.ExtensionContext,
  countingFolderFsPath: string,
  workspaceFileFsPath?: string
): Promise<string> {
  const auto = cfg().get<boolean>('autoResolveFirestoreProject');
  const enabled = typeof auto !== 'boolean' ? true : Boolean(auto);
  if (!enabled) {
    return '';
  }

  const refreshTok = await context.secrets.get(SECRET_REFRESH);
  const apiKey = cfg().get<string>('firebaseApiKey') ?? '';
  const firebaseProjectId = cfg().get<string>('firebaseProjectId') ?? 'tg-work-2026';

  if (!refreshTok?.length || !apiKey?.length) {
    return '';
  }

  const memoKey = `${normPathKey(countingFolderFsPath)}|${
    workspaceFileFsPath ? normPathKey(workspaceFileFsPath) : ''
  }|${firebaseProjectId}`;
  const now = Date.now();
  const m = tgFirestoreResolveMemo;
  if (
    m &&
    m.key === memoKey &&
    m.id !== '' &&
    now - m.atMs < TG_FS_RESOLVE_TTL_MS
  ) {
    return m.id;
  }

  try {
    const access = await refreshIdToken(apiKey, refreshTok);

    const cands = buildIdeFsPathCandidatesForFirestore(
      countingFolderFsPath,
      workspaceFileFsPath
    );
    if (cands.length) {
      const byIde = await firestoreFindFirstProjectMatchingIdeFsPath({
        firebaseProjectId,
        accessToken: access,
        ideFsPathCandidates: cands,
      });
      if (byIde.length) {
        tgFirestoreResolveMemo = { key: memoKey, id: byIde, atMs: now };
        return byIde;
      }
    }

    const bySlug = await firestoreInferProjectIdFromBasenameSlug({
      firebaseProjectId,
      accessToken: access,
      countingFolderFsPath,
    });

    if (bySlug.length) {
      tgFirestoreResolveMemo = { key: memoKey, id: bySlug, atMs: now };
    }
    return bySlug;
  } catch {
    return '';
  }
}

/** `tgWorkProjectId`: primeiro `.tgwork/project.json`; depois Firestore (caminhos / nome pasta). */
async function resolveTgProjectId(
  context: vscode.ExtensionContext,
  countingFolder: string,
  workspaceFile?: string
): Promise<string> {
  const dirs = [
    countingFolder,
    ...(workspaceFile ? [path.dirname(workspaceFile)] : []),
  ];
  const seen = new Set<string>();
  for (const d of dirs) {
    const k = normPathKey(d);
    if (seen.has(k)) {
      continue;
    }
    seen.add(k);
    const json = await loadTgLinkAtProjectRoot(d);
    const pid = linkedProjectId(json);
    if (pid) {
      return pid;
    }
  }
  const firestoreHit = await resolveTgProjectFromFirestoreBestEffort(
    context,
    countingFolder,
    workspaceFile
  );
  return firestoreHit;
}

function canonicalFolderPath(candidate: string | undefined, folders: readonly vscode.WorkspaceFolder[]): string | undefined {
  if (!candidate?.trim()) {
    return undefined;
  }
  const want = normPathKey(candidate.trim());
  const found = folders.find((f) => normPathKey(f.uri.fsPath) === want);
  return found?.uri.fsPath;
}

/** Pastas onde procuramos `.tgwork/project.json` (raízes do workspace + pasta do ficheiro multi-root). */
function workspaceProjectJsonSearchRoots(): string[] {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders?.length) {
    return [];
  }
  const dirs: string[] = folders.map((f) => f.uri.fsPath);
  const ws = vscode.workspace.workspaceFile;
  if (ws?.scheme === 'file') {
    dirs.push(path.dirname(ws.fsPath));
  }
  const out: string[] = [];
  const seen = new Set<string>();
  for (const d of dirs) {
    const k = normPathKey(d);
    if (seen.has(k)) {
      continue;
    }
    seen.add(k);
    out.push(d);
  }
  return out;
}

function linkedIdeCountingFolderFsPath(link: Record<string, unknown>): string {
  const v = link.ideCountingFolderFsPath;
  return typeof v === 'string' ? v.trim() : '';
}

/**
 * Pasta de contagem opcional em `.tgwork/project.json` (campo `ideCountingFolderFsPath`, alinhado com a app TG Work / Firestore).
 */
function resolveCountingFolderFromLinkedJson(): string | undefined {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders?.length) {
    return undefined;
  }
  for (const root of workspaceProjectJsonSearchRoots()) {
    const link = readProjectJsonLinkSync(root);
    const configured = linkedIdeCountingFolderFsPath(link);
    if (!configured) {
      continue;
    }
    const asFolder = canonicalFolderPath(configured, folders);
    if (asFolder) {
      return asFolder;
    }
    const ws = vscode.workspace.workspaceFile;
    if (
      ws?.scheme === 'file' &&
      isWorkspaceShortcutFsPath(configured) &&
      normPathKey(configured) === normPathKey(ws.fsPath)
    ) {
      return folders[0].uri.fsPath;
    }
  }
  return undefined;
}

/**
 * Qual pasta raiz usar para contagem e ligação TG Work.
 * Prioridade: setting `tgWorkIde.countingFolderFsPath` → `.tgwork/project.json` (`ideCountingFolderFsPath`) → escolha guardada na janela → primeira pasta.
 */
function resolveCountingFolderFsPath(context: vscode.ExtensionContext): string | undefined {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders?.length) {
    return undefined;
  }
  const configured = cfg().get<string>('countingFolderFsPath')?.trim() ?? '';
  const fromConfig = canonicalFolderPath(configured || undefined, folders);
  if (fromConfig) {
    return fromConfig;
  }
  const fromLinked = resolveCountingFolderFromLinkedJson();
  if (fromLinked) {
    return fromLinked;
  }
  const saved = context.workspaceState.get<string>(WS_KEY_COUNTING_FOLDER)?.trim() ?? '';
  const fromSaved = canonicalFolderPath(saved || undefined, folders);
  if (fromSaved) {
    return fromSaved;
  }
  return folders[0].uri.fsPath;
}

function buildSessionIdentityKey(
  workspaceFile: string | undefined,
  countingFolderFsPath: string
): string {
  const cf = normPathKey(countingFolderFsPath);
  if (workspaceFile) {
    return `${normPathKey(workspaceFile)}|${cf}`;
  }
  return cf;
}

async function snapshotSessionBase(context: vscode.ExtensionContext): Promise<{
  identityKey: string;
  workspaceFileFsPath?: string;
  countingFolderFsPath: string;
  countingLabel: string;
  workspaceWindowTitle: string;
} | null> {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders?.length) {
    return null;
  }
  const counting = resolveCountingFolderFsPath(context);
  if (!counting) {
    return null;
  }
  const wf = vscode.workspace.workspaceFolders?.find((f) => normPathKey(f.uri.fsPath) === normPathKey(counting));
  const countingLabel = wf?.name ?? path.basename(counting);
  const ws = vscode.workspace.workspaceFile;
  const workspaceFileFsPath = ws?.scheme === 'file' ? ws.fsPath : undefined;

  if (onlyShortcutWorkspaceSetting()) {
    if (!workspaceFileFsPath || !isWorkspaceShortcutFsPath(workspaceFileFsPath)) {
      return null;
    }
  }

  return {
    identityKey: buildSessionIdentityKey(workspaceFileFsPath, counting),
    workspaceFileFsPath,
    countingFolderFsPath: counting,
    countingLabel,
    workspaceWindowTitle: vscode.workspace.name ?? '',
  };
}

/** Guarda a sessão actual no ficheiro local de in-progress (heartbeat ou início). */
function persistInProgress(sess: WindowSession): void {
  const entry: InProgressSession = {
    sessionId: sess.sessionId,
    openedAtMs: sess.openedAtMs,
    lastHeartbeatMs: Date.now(),
    countingLabel: sess.countingLabel,
    countingFolderFsPath: sess.countingFolderFsPath,
    workspaceFileFsPath: sess.workspaceFileFsPath ?? '',
    workspaceWindowTitle: sess.workspaceWindowTitle,
    tgProjectId: sess.tgProjectId,
    editor: detectEditor(),
  };
  try {
    saveInProgressSession(entry);
  } catch {
    // disco cheio ou sem permissão — não bloquear
  }
}

/**
 * HEARTBEAT: a cada N minutos actualiza o ficheiro local in-progress com o timestamp actual.
 * Se o IDE morrer sem gravar, o próximo arranque pede Sim/Não com o último heartbeat.
 */
function startHeartbeat(): void {
  stopHeartbeat();
  const minutes = cfg().get<number>('heartbeatIntervalMinutes') ?? 3;
  const ms = Math.max(1, minutes) * 60_000;
  heartbeatTimer = setInterval(() => {
    const sess = current;
    if (sess) {
      persistInProgress(sess);
    }
  }, ms);
}

function stopHeartbeat(): void {
  if (heartbeatTimer !== undefined) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = undefined;
  }
}

/**
 * Renova o token Firebase proactivamente a cada 50 min enquanto há sessão activa.
 * Garante que no fecho há apenas 1 chamada HTTP (o POST ao Firestore) em vez de 2
 * (refresh token + POST), tornando o deactivate rápido o suficiente para não ser abortado.
 */
async function proactiveTokenRefresh(context: vscode.ExtensionContext): Promise<void> {
  if (cfg().get<boolean>('syncToFirestore') !== true) {
    return;
  }
  const apiKey = cfg().get<string>('firebaseApiKey') ?? '';
  const refreshTok = await context.secrets.get(SECRET_REFRESH);
  if (!apiKey?.length || !refreshTok?.length) {
    return;
  }
  try {
    await refreshIdTokenCached(apiKey, refreshTok);
  } catch {
    // não crítico — o fecho tentará de novo
  }
}

function startTokenRefreshTimer(context: vscode.ExtensionContext): void {
  if (tokenRefreshTimer !== undefined) {
    return;
  }
  // Renovar a cada 50 min (tokens Firebase duram 60 min; 5 min de margem no cache)
  tokenRefreshTimer = setInterval(() => {
    void proactiveTokenRefresh(context);
  }, 50 * 60_000);
}

function stopTokenRefreshTimer(): void {
  if (tokenRefreshTimer !== undefined) {
    clearInterval(tokenRefreshTimer);
    tokenRefreshTimer = undefined;
  }
}

function installHostLifecycleFlushOnce(context: vscode.ExtensionContext): void {
  if (hostLifecycleHooksInstalled) {
    return;
  }
  hostLifecycleHooksInstalled = true;
  const run = () => {
    const ctx = extensionContext ?? context;
    stopHeartbeat();
    void finalizeCurrent(ctx, Date.now(), false, 'sigterm-host');
  };
  try {
    process.once('SIGTERM', run);
    process.once('SIGINT', run);
  } catch {
    //
  }
}

/** Grava no PC (+ Firestore opcional) e limpa sessão actual. Um pedido por vez (deactivate pode coincidir com SIGTERM/Cursor kill). */
function finalizeCurrent(
  context: vscode.ExtensionContext | undefined,
  closedAtMs: number,
  notify: boolean,
  reason: string
): Promise<void> {
  return enqueueFinalize(async () => {
    await finalizeCurrentImpl(context, closedAtMs, notify, reason);
  });
}

async function finalizeCurrentImpl(
  context: vscode.ExtensionContext | undefined,
  closedAtMs: number,
  notify: boolean,
  reason: string
): Promise<void> {
  const sess = current;
  if (!sess) {
    return;
  }

  stopHeartbeat();
  current = undefined;
  if (extensionContext) {
    refreshSessionStatusUi(extensionContext);
  }

  const durationSeconds = Math.max(0, Math.floor((closedAtMs - sess.openedAtMs) / 1000));
  const minSec = cfg().get<number>('minSessionSeconds') ?? 30;
  const editor = detectEditor();

  // Ficheiro local de in-progress — sempre removido ao fechar, independentemente da duração
  clearInProgressSession(sess.sessionId);

  if (durationSeconds < minSec) {
    tgIdeLog(
      `Segmento ${durationSeconds}s abaixo do mínimo ${minSec}s — sessão descartada (tgWorkIde.minSessionSeconds).`
    );
    return;
  }

  // Fecho da janela / SIGTERM: não regista já — pede Sim/Não na próxima abertura
  if (shouldDeferConfirm(reason)) {
    try {
      const pending: PendingConfirmSession = {
        sessionId: sess.sessionId,
        openedAtMs: sess.openedAtMs,
        closedAtMs,
        durationSeconds,
        countingLabel: sess.countingLabel,
        countingFolderFsPath: sess.countingFolderFsPath,
        workspaceFileFsPath: sess.workspaceFileFsPath ?? '',
        workspaceWindowTitle: sess.workspaceWindowTitle,
        tgProjectId: sess.tgProjectId,
        editor,
        reason,
      };
      savePendingConfirmSession(pending);
      tgIdeLog(
        `Fecho: sessão pendente de confirmação · "${sess.countingLabel}" · ${durationSeconds}s · (${reason})`
      );
    } catch (e) {
      tgIdeLog(
        `Fecho: falha ao guardar pendente: ${e instanceof Error ? e.message : String(e)}`
      );
    }
    return;
  }

  const workDateLocal = yyyyMmDdLocal(sess.openedAtMs);
  try {
    const { localPath, cloudOk } = await registerCompletedSession(
      context,
      {
        openedAtMs: sess.openedAtMs,
        closedAtMs,
        durationSeconds,
        countingLabel: sess.countingLabel,
        countingFolderFsPath: sess.countingFolderFsPath,
        workspaceFileFsPath: sess.workspaceFileFsPath ?? '',
        workspaceWindowTitle: sess.workspaceWindowTitle,
        tgProjectId: sess.tgProjectId,
        editor,
      },
      notify
    );
    if (notify) {
      const extra = cloudOk ? ' · nuvem ✓' : '';
      void vscode.window.setStatusBarMessage(
        `TG Work: ${sess.countingLabel} · ${formatDurationHumanPt(durationSeconds)} · ${workDateLocal}${extra}` +
          (localPath ? '' : ''),
        8000
      );
    }
  } catch {
    // já notificado em registerCompletedSession
  }
}

async function startOrRefreshSession(context: vscode.ExtensionContext): Promise<void> {
  const base = await snapshotSessionBase(context);
  if (!base) {
    logIdeSessionSkippedOnce(context);
    await finalizeCurrent(context, Date.now(), false, 'sem workspace');
    return;
  }

  const tgProjectId = await resolveTgProjectId(
    context,
    base.countingFolderFsPath,
    base.workspaceFileFsPath
  );

  if (current?.identityKey === base.identityKey) {
    current.tgProjectId = tgProjectId;
    current.countingLabel = base.countingLabel;
    current.countingFolderFsPath = base.countingFolderFsPath;
    current.workspaceWindowTitle = base.workspaceWindowTitle;
    current.workspaceFileFsPath = base.workspaceFileFsPath;
    refreshSessionStatusUi(context);
    return;
  }

  await finalizeCurrent(context, Date.now(), true, 'mudou pasta de contagem ou workspace');
  const openedAtMs = Date.now();
  current = {
    sessionId: randomUUID(),
    identityKey: base.identityKey,
    workspaceFileFsPath: base.workspaceFileFsPath,
    countingLabel: base.countingLabel,
    countingFolderFsPath: base.countingFolderFsPath,
    workspaceWindowTitle: base.workspaceWindowTitle,
    tgProjectId,
    openedAtMs,
  };
  // Guardar início no PC imediatamente (sem rede)
  persistInProgress(current);
  startHeartbeat();
  startTokenRefreshTimer(context);
  // Pré-aquecer token agora para que o fecho tenha apenas 1 chamada HTTP
  void proactiveTokenRefresh(context);
  tgIdeLog(
    `Sessão INÍCIO: "${base.countingLabel}" · projeto=${tgProjectId || '—'} · ${new Date(openedAtMs).toISOString()} · heartbeat cada ${cfg().get<number>('heartbeatIntervalMinutes') ?? 3}min`
  );
  lastIdeSkipLog = '';
  refreshSessionStatusUi(context);
}

async function pickCountingFolderInteractive(context: vscode.ExtensionContext): Promise<void> {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders?.length) {
    void vscode.window.showErrorMessage('TG Work: não há pastas no workspace.');
    return;
  }

  const configured = cfg().get<string>('countingFolderFsPath')?.trim();
  if (configured) {
    void vscode.window.showWarningMessage(
      'TG Work: tens `tgWorkIde.countingFolderFsPath` definido nas settings — isso tem prioridade sobre a escolha aqui. Limpa esse campo para usar o comando.'
    );
    return;
  }

  const savedNorm = context.workspaceState.get<string>(WS_KEY_COUNTING_FOLDER);
  const savedMatch = savedNorm ? canonicalFolderPath(savedNorm, folders) : undefined;

  type P = vscode.QuickPickItem & { fsPath?: string };
  const choices: P[] = [];
  choices.push({
    label: '$(list-flat) Automático',
    description: 'Usa a primeira pasta raiz do workspace',
    detail: folders[0]?.uri.fsPath,
    fsPath: '__auto__',
    picked: !savedMatch,
  });
  for (const f of folders) {
    choices.push({
      label: `$(folder) ${f.name}`,
      description: f.uri.fsPath,
      fsPath: f.uri.fsPath,
      picked: savedMatch ? normPathKey(f.uri.fsPath) === normPathKey(savedMatch) : false,
    });
  }

  const pick = await vscode.window.showQuickPick(choices, {
    placeHolder: 'Pasta de projeto a contabilizar no tempo e na sessão TG Work',
    matchOnDescription: true,
    matchOnDetail: true,
  });
  if (!pick || !('fsPath' in pick)) {
    return;
  }
  if (pick.fsPath === '__auto__') {
    await context.workspaceState.update(WS_KEY_COUNTING_FOLDER, undefined);
    void vscode.window.showInformationMessage(
      'TG Work: contagem automática (primeira pasta). A sessão actual foi reiniciada se havia outra escolha.'
    );
  } else {
    await context.workspaceState.update(WS_KEY_COUNTING_FOLDER, pick.fsPath);
    void vscode.window.showInformationMessage(
      `TG Work: contagem associada a "${path.basename(pick.fsPath!)}".`
    );
  }

  await finalizeCurrent(context, Date.now(), false, 'mudou-selecao');
  await startOrRefreshSession(context);
}

export async function activate(context: vscode.ExtensionContext): Promise<void> {
  extensionContext = context;

  tgIdeLogChannel = vscode.window.createOutputChannel('TG Work IDE');
  context.subscriptions.push(tgIdeLogChannel);
  tgIdeLog('TG Work IDE Session activada.');
  await recoverAndPromptPendingOnActivate(context).catch(() => undefined);
  // Pré-aquecer token mesmo se não havia sessões pendentes (token fica em cache para o fecho)
  void proactiveTokenRefresh(context);

  context.subscriptions.push(
    vscode.commands.registerCommand('tgWorkIde.showOutput', () => {
      tgIdeLogChannel?.show(true);
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('tgWorkIde.showSessionTotals', () => {
      tgIdeLogChannel?.show(true);
      appendSessionTotalsToLog();
      const { grandTotalSeconds, grandTotalSessions, grandDistinctLocalDays } = summarizeLocalIdeSessions();
      if (grandTotalSessions > 0) {
        void vscode.window.showInformationMessage(
          `TG Work IDE: ${grandTotalSessions} sessão(ões) · ${grandDistinctLocalDays} dias · total ${formatDurationHumanPt(grandTotalSeconds)}`
        );
      }
    })
  );

  async function workspaceFoldersChanged(): Promise<void> {
    const folders = vscode.workspace.workspaceFolders;
    if (!folders?.length) {
      await finalizeCurrent(context, Date.now(), false, 'sem-pastas');
      return;
    }
    await startOrRefreshSession(context);
  }

  context.subscriptions.push(
    vscode.workspace.onDidChangeWorkspaceFolders(() =>
      void workspaceFoldersChanged().catch(() => undefined)
    )
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('tgWorkIde.selectCountingFolder', () =>
      pickCountingFolderInteractive(context).catch(() => undefined)
    )
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('tgWorkIde.flushSession', async () => {
      if (!current) {
        void vscode.window.showInformationMessage(
          onlyShortcutWorkspaceSetting()
            ? 'TG Work: sem sessão activa — abre um *.code-workspace ou define onlyShortcutWorkspace = false.'
            : 'TG Work: sem sessão activa neste momento.'
        );
        return;
      }

      const snapLabel = current.countingLabel;
      const snapSec = Math.max(0, Math.floor((Date.now() - current.openedAtMs) / 1000));

      // Spinner na barra enquanto grava
      const statusHandle = vscode.window.setStatusBarMessage(
        `$(sync~spin) TG Work: a gravar "${snapLabel}"...`,
        30_000
      );

      let cloudOk = false;
      let errorMsg = '';

      try {
        // Capturar cloudOk interceptando o log (solução simples: checar se sessão gravou)
        const closedAtMs = Date.now();
        const sess = current;
        if (sess) {
          stopHeartbeat();
          current = undefined;
          refreshSessionStatusUi(context);

          const durationSeconds = Math.max(0, Math.floor((closedAtMs - sess.openedAtMs) / 1000));
          const minSec = cfg().get<number>('minSessionSeconds') ?? 30;
          const editor = detectEditor();
          clearInProgressSession(sess.sessionId);

          if (durationSeconds < minSec) {
            statusHandle.dispose();
            void vscode.window.showWarningMessage(
              `TG Work: só ${formatDurationHumanPt(durationSeconds)} — mínimo é ${minSec}s (tgWorkIde.minSessionSeconds). Contagem recomeçada.`
            );
            await startOrRefreshSession(context);
            return;
          }

          const openedIso = new Date(sess.openedAtMs).toISOString();
          const closedIso = new Date(closedAtMs).toISOString();
          const workDateLocal = yyyyMmDdLocal(sess.openedAtMs);

          // PC
          try {
            appendIdeSessionLocally({
              recordedAt: closedIso,
              workDateLocal,
              openedAt: openedIso,
              closedAt: closedIso,
              durationSeconds,
              workspaceShortcut: sess.workspaceFileFsPath ?? '',
              workspaceMode: sess.workspaceFileFsPath ? 'code-workspace' : 'folder',
              workspaceRoot: sess.countingFolderFsPath,
              workspaceName: sess.countingLabel,
              workspaceWindowTitle: sess.workspaceWindowTitle,
              countingFolderFsPath: sess.countingFolderFsPath,
              tgProjectId: sess.tgProjectId || '',
              editor,
              countingMode: 'window-open-to-close',
            });
            tgIdeLog(`PC: gravado · ${sess.countingLabel} · ${durationSeconds}s · dia=${workDateLocal}`);
          } catch (e) {
            tgIdeLog(`PC: falha: ${e instanceof Error ? e.message : String(e)}`);
          }

          // Firestore
          const syncCloud = cfg().get<boolean>('syncToFirestore') === true;
          if (syncCloud) {
            const uid = await context.secrets.get(SECRET_UID);
            const refreshTok = await context.secrets.get(SECRET_REFRESH);
            const apiKey = cfg().get<string>('firebaseApiKey') ?? '';
            const projectId = cfg().get<string>('firebaseProjectId') ?? 'tg-work-2026';
            if (uid && refreshTok && apiKey) {
              try {
                const access = await refreshIdTokenCached(apiKey, refreshTok);
                const docId = randomUUID();
                const body = ideSessionFirestoreFields({
                  userId: uid,
                  tgProjectId: sess.tgProjectId || '',
                  workspaceRoot: sess.countingFolderFsPath,
                  workspaceName: sess.countingLabel,
                  editor,
                  openedAtMs: sess.openedAtMs,
                  closedAtMs,
                  durationSeconds,
                });
                await firestoreCreateSessionLog({
                  projectId,
                  documentId: docId,
                  accessToken: access,
                  payload: body,
                });
                cloudOk = true;
                tgIdeLog(`Firestore: gravado · ${sess.countingLabel} · ${durationSeconds}s · dia=${workDateLocal} · doc=${docId}`);
              } catch (e) {
                errorMsg = e instanceof Error ? e.message : String(e);
                tgIdeLog(`Firestore FALHOU: ${errorMsg}`);
              }
            } else {
              errorMsg = 'sem login Firebase (comando «iniciar sessão Firebase»)';
              tgIdeLog(`Firestore: ${errorMsg}`);
            }
          }

          statusHandle.dispose();
          const durStr = formatDurationHumanPt(durationSeconds);
          if (cloudOk) {
            void vscode.window.showInformationMessage(
              `TG Work ✓ Gravado: "${sess.countingLabel}" · ${durStr} · ${workDateLocal}`,
              'Ver Saída'
            ).then((pick) => {
              if (pick === 'Ver Saída') {
                tgIdeLogChannel?.show(true);
              }
            });
          } else if (syncCloud) {
            void vscode.window.showWarningMessage(
              `TG Work: PC gravado, Firestore falhou: ${errorMsg}`,
              'Ver Saída'
            ).then((pick) => {
              if (pick === 'Ver Saída') {
                tgIdeLogChannel?.show(true);
              }
            });
          } else {
            void vscode.window.showInformationMessage(
              `TG Work: "${sess.countingLabel}" · ${durStr} · gravado no PC (sync nuvem desligado).`
            );
          }
        }
      } catch (e) {
        statusHandle.dispose();
        void vscode.window.showErrorMessage(`TG Work: erro ao gravar: ${e instanceof Error ? e.message : String(e)}`);
      }

      await startOrRefreshSession(context);
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('tgWorkIde.openLocalLogs', async () => {
      const dir = path.dirname(localIdeSessionsFilePath());
      await vscode.env.openExternal(vscode.Uri.file(dir));
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('tgWorkIde.firebaseLoginHelp', async () => {
      const mdPath = path.join(context.extensionPath, 'FIREBASE_LOGIN.md');
      const uri = vscode.Uri.file(mdPath);
      const open = await vscode.window.showWarningMessage(
        'A TG Work IDE usa apenas Email + palavra‑passe Firebase (não há «Continuar com Google» aqui).',
        'Abrir FIREBASE_LOGIN.md',
        'Fechar'
      );
      if (open === 'Abrir FIREBASE_LOGIN.md') {
        try {
          const doc = await vscode.workspace.openTextDocument(uri);
          await vscode.window.showTextDocument(doc, { preview: true });
        } catch {
          void vscode.window.showErrorMessage(`Não encontrei o ficheiro: ${mdPath}`);
        }
      }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('tgWorkIde.signIn', async () => {
      const apiKey = cfg().get<string>('firebaseApiKey') ?? '';
      if (!apiKey) {
        void vscode.window.showErrorMessage('Configura `tgWorkIde.firebaseApiKey`.');
        return;
      }
      const email = await vscode.window.showInputBox({
        title: 'TG Work IDE — Login Firebase',
        prompt: 'Email (mesmo que na app TG Work, com palavra-passe Firebase)',
        placeHolder: 'exemplo@email.com',
        ignoreFocusOut: true,
      });
      if (email === undefined) {
        void vscode.window.showInformationMessage('TG Work IDE: login cancelado.');
        return;
      }
      const emailTrim = email.trim();
      if (!emailTrim) {
        void vscode.window.showWarningMessage('TG Work IDE: indica um email.');
        return;
      }
      const password = await vscode.window.showInputBox({
        title: 'TG Work IDE — Login Firebase',
        prompt: 'Palavra-passe Firebase deste email',
        password: true,
        ignoreFocusOut: true,
      });
      if (password === undefined) {
        void vscode.window.showInformationMessage('TG Work IDE: login cancelado.');
        return;
      }
      if (!password) {
        void vscode.window.showWarningMessage('TG Work IDE: indica a palavra-passe.');
        return;
      }
      try {
        const r = await signInWithPassword(apiKey, emailTrim, password);
        await context.secrets.store(SECRET_REFRESH, r.refreshToken);
        await context.secrets.store(SECRET_UID, r.localId);
        void vscode.window.showInformationMessage('TG Work IDE: sessão Firebase iniciada.');
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        const pick = await vscode.window.showErrorMessage(msg, 'Ajuda login Firebase…');
        if (pick === 'Ajuda login Firebase…') {
          await vscode.commands.executeCommand('tgWorkIde.firebaseLoginHelp');
        }
      }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('tgWorkIde.signOut', async () => {
      await context.secrets.delete(SECRET_REFRESH);
      await context.secrets.delete(SECRET_UID);
      tgFirestoreResolveMemo = undefined;
      clearAccessTokenCache();
      void vscode.window.showInformationMessage('TG Work IDE: sessão Firebase terminada.');
    })
  );

  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (
        e.affectsConfiguration('tgWorkIde.countingFolderFsPath') ||
        e.affectsConfiguration('tgWorkIde.syncToFirestore') ||
        e.affectsConfiguration('tgWorkIde.autoResolveFirestoreProject') ||
        e.affectsConfiguration('tgWorkIde.minSessionSeconds') ||
        e.affectsConfiguration('tgWorkIde.onlyShortcutWorkspace')
      ) {
        void startOrRefreshSession(context).catch(() => undefined);
      }
    })
  );

  await workspaceFoldersChanged();
  setTimeout(() => void workspaceFoldersChanged(), 750);
  installHostLifecycleFlushOnce(context);
}

export async function deactivate(): Promise<void> {
  stopHeartbeat();
  stopTokenRefreshTimer();
  disposeSessionStatusTicker();
  const ctx = extensionContext;
  if (current && ctx) {
    // Aviso visual imediato — o utilizador vê que algo está a acontecer
    void vscode.window.setStatusBarMessage(
      '$(sync~spin) TG Work: a guardar sessão (confirma na próxima abertura)...',
      10_000
    );
  }
  try {
    await finalizeCurrent(ctx, Date.now(), false, 'fecho-janela');
  } catch {
    //
  }
  extensionContext = undefined;
}
