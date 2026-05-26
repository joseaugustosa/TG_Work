"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = activate;
exports.deactivate = deactivate;
const vscode = require("vscode");
const fs = require("fs");
const path = require("path");
const crypto_1 = require("crypto");
const firebaseRest_1 = require("./firebaseRest");
const localLog_1 = require("./localLog");
const SECRET_REFRESH = 'tgWorkIde.refresh_token';
const SECRET_UID = 'tgWorkIde.local_id';
/** Ver → Saída → «TG Work IDE» — histórico de gravações PC/Firestore. */
let tgIdeLogChannel;
function tgIdeLog(line) {
    tgIdeLogChannel?.appendLine(`[${new Date().toISOString()}] ${line}`);
}
/** Relógio na barra de estado — sessão actual (ainda não está no JSONL até fechar). */
let sessionStatusBar;
let sessionStatusInterval;
function disposeSessionStatusTicker() {
    if (sessionStatusInterval !== undefined) {
        clearInterval(sessionStatusInterval);
        sessionStatusInterval = undefined;
    }
}
function ensureSessionStatusBar(context) {
    if (!sessionStatusBar) {
        sessionStatusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 101);
        sessionStatusBar.command = 'tgWorkIde.flushSession';
        context.subscriptions.push(sessionStatusBar);
    }
    return sessionStatusBar;
}
function refreshSessionStatusUi(context) {
    const sb = ensureSessionStatusBar(context);
    const sess = current;
    if (!sess) {
        sb.hide();
        disposeSessionStatusTicker();
        return;
    }
    const sec = Math.max(0, Math.floor((Date.now() - sess.openedAtMs) / 1000));
    sb.text = `$(cloud-upload) TG Work · ${sess.countingLabel} · ${(0, localLog_1.formatDurationHumanPt)(sec)}`;
    sb.tooltip =
        `Projeto: ${sess.countingLabel}\nTempo desde abertura: ${(0, localLog_1.formatDurationHumanPt)(sec)}\n\nClique → Gravar sessão agora no Firestore e recomeçar contagem.\n(O fecho da janela também grava automaticamente.)`;
    sb.show();
    if (sessionStatusInterval === undefined) {
        sessionStatusInterval = setInterval(() => refreshSessionStatusUi(context), 15000);
    }
}
function appendSessionTotalsToLog() {
    const fp = (0, localLog_1.localIdeSessionsFilePath)();
    const { rows, grandTotalSeconds, grandTotalSessions, grandDistinctLocalDays, parseErrors } = (0, localLog_1.summarizeLocalIdeSessions)(fp);
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
        tgIdeLog(`· ${(0, localLog_1.formatDurationHumanPt)(r.totalSeconds)}  (${r.sessionCount} sess. · ${r.distinctLocalDays} dias)  ${r.workspaceName || '?'}  [${idPart}]`);
        if (r.workspaceRoot) {
            tgIdeLog(`    pasta: ${r.workspaceRoot}`);
        }
    }
    tgIdeLog(`TOTAL GERAL: ${grandTotalSessions} sessões · ${grandDistinctLocalDays} dias distintos · ${(0, localLog_1.formatDurationHumanPt)(grandTotalSeconds)} (${grandTotalSeconds}s)`);
    if (parseErrors > 0) {
        tgIdeLog(`Aviso: ${parseErrors} linha(s) ignoradas (JSON inválido).`);
    }
    tgIdeLog('────────────────────────────────────────────────────────────────────');
}
/** Evita repetir a mesma linha quando o workspace oscila durante o arranque. */
let lastIdeSkipLog = '';
/** Persiste a pasta escolhida para contagem nesta janela de workspace. */
const WS_KEY_COUNTING_FOLDER = 'tgWorkIde.countingFolderFsPath.v1';
function explainWhyIdeSessionSkipped(context) {
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
function logIdeSessionSkippedOnce(context) {
    const line = `Sessão IDE não iniciada: ${explainWhyIdeSessionSkipped(context)}`;
    if (line === lastIdeSkipLog) {
        return;
    }
    lastIdeSkipLog = line;
    tgIdeLog(line);
}
let extensionContext;
let current;
let hostLifecycleHooksInstalled = false;
let heartbeatTimer;
/** Renova o token proactivamente para que o fecho tenha apenas 1 chamada HTTP. */
let tokenRefreshTimer;
/** Evita dois finalize em paralelo (deactivate + sigterm ou comando manual). */
let finalizeMutex = Promise.resolve();
function enqueueFinalize(task) {
    const next = finalizeMutex.then(task, task);
    finalizeMutex = next.catch(() => undefined);
    return next;
}
/**
 * Ao arrancar, verifica se há ficheiros in-progress de sessões que não fecharam (crash / kill).
 * Para cada um, envia ao Firestore usando o último heartbeat como hora de fecho.
 */
async function recoverPendingSessionsOnActivate(context) {
    if (cfg().get('syncToFirestore') !== true) {
        return;
    }
    const pending = (0, localLog_1.readAllPendingInProgress)();
    if (!pending.length) {
        return;
    }
    const apiKey = cfg().get('firebaseApiKey') ?? '';
    const refreshTok = await context.secrets.get(SECRET_REFRESH);
    if (!apiKey?.length || !refreshTok?.length) {
        tgIdeLog(`Recuperação: ${pending.length} sessão(ões) pendente(s) — sem login Firebase para enviar (comando «iniciar sessão Firebase»).`);
        return;
    }
    const uid = await context.secrets.get(SECRET_UID);
    if (!uid?.length) {
        return;
    }
    let access = '';
    try {
        access = await (0, firebaseRest_1.refreshIdTokenCached)(apiKey, refreshTok);
    }
    catch (e) {
        tgIdeLog(`Recuperação: token falhou: ${e instanceof Error ? e.message : String(e)}`);
        return;
    }
    const firebaseProjectId = cfg().get('firebaseProjectId') ?? 'tg-work-2026';
    const minSec = cfg().get('minSessionSeconds') ?? 30;
    const now = Date.now();
    for (const p of pending) {
        const closedAtMs = Math.max(p.lastHeartbeatMs, p.openedAtMs + 1000);
        const durationSeconds = Math.max(0, Math.floor((closedAtMs - p.openedAtMs) / 1000));
        const ageDays = (now - p.openedAtMs) / 86400000;
        if (ageDays > 45) {
            (0, localLog_1.clearInProgressSession)(p.sessionId);
            tgIdeLog(`Recuperação: omitida (>45 dias) · "${p.countingLabel}"`);
            continue;
        }
        if (durationSeconds < minSec) {
            (0, localLog_1.clearInProgressSession)(p.sessionId);
            tgIdeLog(`Recuperação: omitida (${durationSeconds}s < mínimo ${minSec}s) · "${p.countingLabel}"`);
            continue;
        }
        try {
            const docId = (0, crypto_1.randomUUID)();
            const body = (0, firebaseRest_1.ideSessionFirestoreFields)({
                userId: uid,
                tgProjectId: p.tgProjectId || '',
                workspaceRoot: p.countingFolderFsPath,
                workspaceName: p.countingLabel,
                editor: p.editor,
                openedAtMs: p.openedAtMs,
                closedAtMs,
                durationSeconds,
            });
            await (0, firebaseRest_1.firestoreCreateSessionLog)({
                projectId: firebaseProjectId,
                documentId: docId,
                accessToken: access,
                payload: body,
            });
            (0, localLog_1.clearInProgressSession)(p.sessionId);
            tgIdeLog(`Recuperação: sessão enviada (IDE fechou sem gravar) · "${p.countingLabel}" · ${durationSeconds}s · doc=${docId}`);
        }
        catch (e) {
            tgIdeLog(`Recuperação: falhou (${p.countingLabel}): ${e instanceof Error ? e.message : String(e)}`);
        }
    }
}
function normPathKey(fsPath) {
    const n = path.normalize(fsPath);
    return process.platform === 'win32' ? n.toLowerCase() : n;
}
function detectEditor() {
    const n = vscode.env.appName.toLowerCase();
    if (n.includes('cursor')) {
        return 'cursor';
    }
    if (n.includes('insiders')) {
        return 'vscode_insiders';
    }
    return 'vscode';
}
function cfg() {
    return vscode.workspace.getConfiguration('tgWorkIde');
}
/** Atalho multi‑root: `*.code-workspace` ou `*.cursor-workspace`. */
function isWorkspaceShortcutFsPath(fsPath) {
    const lower = fsPath.trim().toLowerCase();
    return lower.endsWith('.code-workspace') || lower.endsWith('.cursor-workspace');
}
/**
 * Modo restrito: só conta quando há `*.code-workspace` / `*.cursor-workspace`.
 * Tem de estar explicitamente **true** nas settings — não usar `!== false` porque o defeito do manifest já conta como valor real.
 */
function onlyShortcutWorkspaceSetting() {
    return cfg().get('onlyShortcutWorkspace') === true;
}
function yyyyMmDdLocal(epochMs) {
    const d = new Date(epochMs);
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
}
function readProjectJsonLinkSync(folderRootContainingTgWork) {
    try {
        const p = path.join(folderRootContainingTgWork, '.tgwork', 'project.json');
        const txt = fs.readFileSync(p, 'utf8');
        return JSON.parse(txt);
    }
    catch {
        return {};
    }
}
async function loadTgLinkAtProjectRoot(folderRootContainingTgWork) {
    return readProjectJsonLinkSync(folderRootContainingTgWork);
}
function linkedProjectId(link) {
    const a = link.tgWorkProjectId ?? link.projectId;
    return typeof a === 'string' ? a : '';
}
let tgFirestoreResolveMemo;
const TG_FS_RESOLVE_TTL_MS = 120000;
function uniqPathCandidates(paths) {
    const seen = new Set();
    const out = [];
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
function buildIdeFsPathCandidatesForFirestore(countingFolderFsPath, workspaceFileFsPath) {
    const acc = [];
    function variantsOf(fsPathNorm) {
        const n = path.normalize(fsPathNorm.trim());
        if (!n) {
            return [];
        }
        if (process.platform !== 'win32') {
            return [n];
        }
        const variants = new Set([n]);
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
async function resolveTgProjectFromFirestoreBestEffort(context, countingFolderFsPath, workspaceFileFsPath) {
    const auto = cfg().get('autoResolveFirestoreProject');
    const enabled = typeof auto !== 'boolean' ? true : Boolean(auto);
    if (!enabled) {
        return '';
    }
    const refreshTok = await context.secrets.get(SECRET_REFRESH);
    const apiKey = cfg().get('firebaseApiKey') ?? '';
    const firebaseProjectId = cfg().get('firebaseProjectId') ?? 'tg-work-2026';
    if (!refreshTok?.length || !apiKey?.length) {
        return '';
    }
    const memoKey = `${normPathKey(countingFolderFsPath)}|${workspaceFileFsPath ? normPathKey(workspaceFileFsPath) : ''}|${firebaseProjectId}`;
    const now = Date.now();
    const m = tgFirestoreResolveMemo;
    if (m &&
        m.key === memoKey &&
        m.id !== '' &&
        now - m.atMs < TG_FS_RESOLVE_TTL_MS) {
        return m.id;
    }
    try {
        const access = await (0, firebaseRest_1.refreshIdToken)(apiKey, refreshTok);
        const cands = buildIdeFsPathCandidatesForFirestore(countingFolderFsPath, workspaceFileFsPath);
        if (cands.length) {
            const byIde = await (0, firebaseRest_1.firestoreFindFirstProjectMatchingIdeFsPath)({
                firebaseProjectId,
                accessToken: access,
                ideFsPathCandidates: cands,
            });
            if (byIde.length) {
                tgFirestoreResolveMemo = { key: memoKey, id: byIde, atMs: now };
                return byIde;
            }
        }
        const bySlug = await (0, firebaseRest_1.firestoreInferProjectIdFromBasenameSlug)({
            firebaseProjectId,
            accessToken: access,
            countingFolderFsPath,
        });
        if (bySlug.length) {
            tgFirestoreResolveMemo = { key: memoKey, id: bySlug, atMs: now };
        }
        return bySlug;
    }
    catch {
        return '';
    }
}
/** `tgWorkProjectId`: primeiro `.tgwork/project.json`; depois Firestore (caminhos / nome pasta). */
async function resolveTgProjectId(context, countingFolder, workspaceFile) {
    const dirs = [
        countingFolder,
        ...(workspaceFile ? [path.dirname(workspaceFile)] : []),
    ];
    const seen = new Set();
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
    const firestoreHit = await resolveTgProjectFromFirestoreBestEffort(context, countingFolder, workspaceFile);
    return firestoreHit;
}
function canonicalFolderPath(candidate, folders) {
    if (!candidate?.trim()) {
        return undefined;
    }
    const want = normPathKey(candidate.trim());
    const found = folders.find((f) => normPathKey(f.uri.fsPath) === want);
    return found?.uri.fsPath;
}
/** Pastas onde procuramos `.tgwork/project.json` (raízes do workspace + pasta do ficheiro multi-root). */
function workspaceProjectJsonSearchRoots() {
    const folders = vscode.workspace.workspaceFolders;
    if (!folders?.length) {
        return [];
    }
    const dirs = folders.map((f) => f.uri.fsPath);
    const ws = vscode.workspace.workspaceFile;
    if (ws?.scheme === 'file') {
        dirs.push(path.dirname(ws.fsPath));
    }
    const out = [];
    const seen = new Set();
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
function linkedIdeCountingFolderFsPath(link) {
    const v = link.ideCountingFolderFsPath;
    return typeof v === 'string' ? v.trim() : '';
}
/**
 * Pasta de contagem opcional em `.tgwork/project.json` (campo `ideCountingFolderFsPath`, alinhado com a app TG Work / Firestore).
 */
function resolveCountingFolderFromLinkedJson() {
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
        if (ws?.scheme === 'file' &&
            isWorkspaceShortcutFsPath(configured) &&
            normPathKey(configured) === normPathKey(ws.fsPath)) {
            return folders[0].uri.fsPath;
        }
    }
    return undefined;
}
/**
 * Qual pasta raiz usar para contagem e ligação TG Work.
 * Prioridade: setting `tgWorkIde.countingFolderFsPath` → `.tgwork/project.json` (`ideCountingFolderFsPath`) → escolha guardada na janela → primeira pasta.
 */
function resolveCountingFolderFsPath(context) {
    const folders = vscode.workspace.workspaceFolders;
    if (!folders?.length) {
        return undefined;
    }
    const configured = cfg().get('countingFolderFsPath')?.trim() ?? '';
    const fromConfig = canonicalFolderPath(configured || undefined, folders);
    if (fromConfig) {
        return fromConfig;
    }
    const fromLinked = resolveCountingFolderFromLinkedJson();
    if (fromLinked) {
        return fromLinked;
    }
    const saved = context.workspaceState.get(WS_KEY_COUNTING_FOLDER)?.trim() ?? '';
    const fromSaved = canonicalFolderPath(saved || undefined, folders);
    if (fromSaved) {
        return fromSaved;
    }
    return folders[0].uri.fsPath;
}
function buildSessionIdentityKey(workspaceFile, countingFolderFsPath) {
    const cf = normPathKey(countingFolderFsPath);
    if (workspaceFile) {
        return `${normPathKey(workspaceFile)}|${cf}`;
    }
    return cf;
}
async function snapshotSessionBase(context) {
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
function persistInProgress(sess) {
    const entry = {
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
        (0, localLog_1.saveInProgressSession)(entry);
    }
    catch {
        // disco cheio ou sem permissão — não bloquear
    }
}
/**
 * HEARTBEAT: a cada N minutos actualiza o ficheiro local in-progress com o timestamp actual.
 * Se o IDE morrer sem gravar, o próximo arranque envia o último estado ao Firestore.
 */
function startHeartbeat() {
    stopHeartbeat();
    const minutes = cfg().get('heartbeatIntervalMinutes') ?? 3;
    const ms = Math.max(1, minutes) * 60000;
    heartbeatTimer = setInterval(() => {
        const sess = current;
        if (sess) {
            persistInProgress(sess);
        }
    }, ms);
}
function stopHeartbeat() {
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
async function proactiveTokenRefresh(context) {
    if (cfg().get('syncToFirestore') !== true) {
        return;
    }
    const apiKey = cfg().get('firebaseApiKey') ?? '';
    const refreshTok = await context.secrets.get(SECRET_REFRESH);
    if (!apiKey?.length || !refreshTok?.length) {
        return;
    }
    try {
        await (0, firebaseRest_1.refreshIdTokenCached)(apiKey, refreshTok);
    }
    catch {
        // não crítico — o fecho tentará de novo
    }
}
function startTokenRefreshTimer(context) {
    if (tokenRefreshTimer !== undefined) {
        return;
    }
    // Renovar a cada 50 min (tokens Firebase duram 60 min; 5 min de margem no cache)
    tokenRefreshTimer = setInterval(() => {
        void proactiveTokenRefresh(context);
    }, 50 * 60000);
}
function stopTokenRefreshTimer() {
    if (tokenRefreshTimer !== undefined) {
        clearInterval(tokenRefreshTimer);
        tokenRefreshTimer = undefined;
    }
}
function installHostLifecycleFlushOnce(context) {
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
    }
    catch {
        //
    }
}
/** Grava no PC (+ Firestore opcional) e limpa sessão actual. Um pedido por vez (deactivate pode coincidir com SIGTERM/Cursor kill). */
function finalizeCurrent(context, closedAtMs, notify, reason) {
    return enqueueFinalize(async () => {
        await finalizeCurrentImpl(context, closedAtMs, notify, reason);
    });
}
async function finalizeCurrentImpl(context, closedAtMs, notify, reason) {
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
    const minSec = cfg().get('minSessionSeconds') ?? 30;
    const editor = detectEditor();
    // Ficheiro local de in-progress — sempre removido ao fechar, independentemente da duração
    (0, localLog_1.clearInProgressSession)(sess.sessionId);
    if (durationSeconds < minSec) {
        tgIdeLog(`Segmento ${durationSeconds}s abaixo do mínimo ${minSec}s — sessão descartada (tgWorkIde.minSessionSeconds).`);
        return;
    }
    const openedIso = new Date(sess.openedAtMs).toISOString();
    const closedIso = new Date(closedAtMs).toISOString();
    const workDateLocal = yyyyMmDdLocal(sess.openedAtMs);
    // ── 1. Guardar no PC (sessions.jsonl) ─────────────────────────────────────
    let localPath = '';
    try {
        localPath = (0, localLog_1.appendIdeSessionLocally)({
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
        tgIdeLog(`PC: gravado · ${sess.countingLabel} · ${durationSeconds}s · dia=${workDateLocal} · ${path.basename(localPath)}`);
    }
    catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        tgIdeLog(`PC: falha ao gravar: ${msg}`);
        if (notify) {
            void vscode.window.showErrorMessage(`TG Work IDE: falha ao gravar no PC: ${msg}`);
        }
    }
    // ── 2. Enviar ao Firestore (um único POST com dados completos) ────────────
    const syncCloud = cfg().get('syncToFirestore') === true;
    let cloudOk = false;
    const showCloudErrorsInUi = notify || reason.includes('fecho') || reason.includes('sigterm-host');
    if (syncCloud && context) {
        const uid = await context.secrets.get(SECRET_UID);
        const refreshTok = await context.secrets.get(SECRET_REFRESH);
        const apiKey = cfg().get('firebaseApiKey') ?? '';
        const projectId = cfg().get('firebaseProjectId') ?? 'tg-work-2026';
        if (uid && refreshTok && apiKey) {
            try {
                const access = await (0, firebaseRest_1.refreshIdTokenCached)(apiKey, refreshTok);
                const docId = (0, crypto_1.randomUUID)();
                const body = (0, firebaseRest_1.ideSessionFirestoreFields)({
                    userId: uid,
                    tgProjectId: sess.tgProjectId || '',
                    workspaceRoot: sess.countingFolderFsPath,
                    workspaceName: sess.countingLabel,
                    editor,
                    openedAtMs: sess.openedAtMs,
                    closedAtMs,
                    durationSeconds,
                });
                await (0, firebaseRest_1.firestoreCreateSessionLog)({
                    projectId,
                    documentId: docId,
                    accessToken: access,
                    payload: body,
                });
                cloudOk = true;
                tgIdeLog(`Firestore: gravado · ${sess.countingLabel} · ${durationSeconds}s · dia=${workDateLocal} · doc=${docId}`);
            }
            catch (e) {
                const msg = e instanceof Error ? e.message : String(e);
                tgIdeLog(`Firestore FALHOU: ${msg}`);
                if (showCloudErrorsInUi) {
                    void vscode.window.showWarningMessage(`TG Work: Firestore: ${msg}`);
                }
            }
        }
        else {
            tgIdeLog('Firestore: sem login — usa «TG Work IDE: iniciar sessão Firebase». Sessão gravada só no PC.');
            if (showCloudErrorsInUi) {
                void vscode.window.showWarningMessage('TG Work: sem login Firebase — sessão só no PC.');
            }
        }
    }
    if (notify) {
        const fn = localPath ? path.basename(localPath) : '—';
        const extra = cloudOk ? ' · nuvem ✓' : '';
        void vscode.window.setStatusBarMessage(`TG Work: ${sess.countingLabel} · ${(0, localLog_1.formatDurationHumanPt)(durationSeconds)} · ${workDateLocal}${extra}`, 8000);
    }
}
async function startOrRefreshSession(context) {
    const base = await snapshotSessionBase(context);
    if (!base) {
        logIdeSessionSkippedOnce(context);
        await finalizeCurrent(context, Date.now(), false, 'sem workspace');
        return;
    }
    const tgProjectId = await resolveTgProjectId(context, base.countingFolderFsPath, base.workspaceFileFsPath);
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
        sessionId: (0, crypto_1.randomUUID)(),
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
    tgIdeLog(`Sessão INÍCIO: "${base.countingLabel}" · projeto=${tgProjectId || '—'} · ${new Date(openedAtMs).toISOString()} · heartbeat cada ${cfg().get('heartbeatIntervalMinutes') ?? 3}min`);
    lastIdeSkipLog = '';
    refreshSessionStatusUi(context);
}
async function pickCountingFolderInteractive(context) {
    const folders = vscode.workspace.workspaceFolders;
    if (!folders?.length) {
        void vscode.window.showErrorMessage('TG Work: não há pastas no workspace.');
        return;
    }
    const configured = cfg().get('countingFolderFsPath')?.trim();
    if (configured) {
        void vscode.window.showWarningMessage('TG Work: tens `tgWorkIde.countingFolderFsPath` definido nas settings — isso tem prioridade sobre a escolha aqui. Limpa esse campo para usar o comando.');
        return;
    }
    const savedNorm = context.workspaceState.get(WS_KEY_COUNTING_FOLDER);
    const savedMatch = savedNorm ? canonicalFolderPath(savedNorm, folders) : undefined;
    const choices = [];
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
        void vscode.window.showInformationMessage('TG Work: contagem automática (primeira pasta). A sessão actual foi reiniciada se havia outra escolha.');
    }
    else {
        await context.workspaceState.update(WS_KEY_COUNTING_FOLDER, pick.fsPath);
        void vscode.window.showInformationMessage(`TG Work: contagem associada a "${path.basename(pick.fsPath)}".`);
    }
    await finalizeCurrent(context, Date.now(), false, 'mudou-selecao');
    await startOrRefreshSession(context);
}
async function activate(context) {
    extensionContext = context;
    tgIdeLogChannel = vscode.window.createOutputChannel('TG Work IDE');
    context.subscriptions.push(tgIdeLogChannel);
    tgIdeLog('TG Work IDE Session activada.');
    await recoverPendingSessionsOnActivate(context).catch(() => undefined);
    // Pré-aquecer token mesmo se não havia sessões pendentes (token fica em cache para o fecho)
    void proactiveTokenRefresh(context);
    context.subscriptions.push(vscode.commands.registerCommand('tgWorkIde.showOutput', () => {
        tgIdeLogChannel?.show(true);
    }));
    context.subscriptions.push(vscode.commands.registerCommand('tgWorkIde.showSessionTotals', () => {
        tgIdeLogChannel?.show(true);
        appendSessionTotalsToLog();
        const { grandTotalSeconds, grandTotalSessions, grandDistinctLocalDays } = (0, localLog_1.summarizeLocalIdeSessions)();
        if (grandTotalSessions > 0) {
            void vscode.window.showInformationMessage(`TG Work IDE: ${grandTotalSessions} sessão(ões) · ${grandDistinctLocalDays} dias · total ${(0, localLog_1.formatDurationHumanPt)(grandTotalSeconds)}`);
        }
    }));
    async function workspaceFoldersChanged() {
        const folders = vscode.workspace.workspaceFolders;
        if (!folders?.length) {
            await finalizeCurrent(context, Date.now(), false, 'sem-pastas');
            return;
        }
        await startOrRefreshSession(context);
    }
    context.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders(() => void workspaceFoldersChanged().catch(() => undefined)));
    context.subscriptions.push(vscode.commands.registerCommand('tgWorkIde.selectCountingFolder', () => pickCountingFolderInteractive(context).catch(() => undefined)));
    context.subscriptions.push(vscode.commands.registerCommand('tgWorkIde.flushSession', async () => {
        if (!current) {
            void vscode.window.showInformationMessage(onlyShortcutWorkspaceSetting()
                ? 'TG Work: sem sessão activa — abre um *.code-workspace ou define onlyShortcutWorkspace = false.'
                : 'TG Work: sem sessão activa neste momento.');
            return;
        }
        const snapLabel = current.countingLabel;
        const snapSec = Math.max(0, Math.floor((Date.now() - current.openedAtMs) / 1000));
        // Spinner na barra enquanto grava
        const statusHandle = vscode.window.setStatusBarMessage(`$(sync~spin) TG Work: a gravar "${snapLabel}"...`, 30000);
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
                const minSec = cfg().get('minSessionSeconds') ?? 30;
                const editor = detectEditor();
                (0, localLog_1.clearInProgressSession)(sess.sessionId);
                if (durationSeconds < minSec) {
                    statusHandle.dispose();
                    void vscode.window.showWarningMessage(`TG Work: só ${(0, localLog_1.formatDurationHumanPt)(durationSeconds)} — mínimo é ${minSec}s (tgWorkIde.minSessionSeconds). Contagem recomeçada.`);
                    await startOrRefreshSession(context);
                    return;
                }
                const openedIso = new Date(sess.openedAtMs).toISOString();
                const closedIso = new Date(closedAtMs).toISOString();
                const workDateLocal = yyyyMmDdLocal(sess.openedAtMs);
                // PC
                try {
                    (0, localLog_1.appendIdeSessionLocally)({
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
                }
                catch (e) {
                    tgIdeLog(`PC: falha: ${e instanceof Error ? e.message : String(e)}`);
                }
                // Firestore
                const syncCloud = cfg().get('syncToFirestore') === true;
                if (syncCloud) {
                    const uid = await context.secrets.get(SECRET_UID);
                    const refreshTok = await context.secrets.get(SECRET_REFRESH);
                    const apiKey = cfg().get('firebaseApiKey') ?? '';
                    const projectId = cfg().get('firebaseProjectId') ?? 'tg-work-2026';
                    if (uid && refreshTok && apiKey) {
                        try {
                            const access = await (0, firebaseRest_1.refreshIdTokenCached)(apiKey, refreshTok);
                            const docId = (0, crypto_1.randomUUID)();
                            const body = (0, firebaseRest_1.ideSessionFirestoreFields)({
                                userId: uid,
                                tgProjectId: sess.tgProjectId || '',
                                workspaceRoot: sess.countingFolderFsPath,
                                workspaceName: sess.countingLabel,
                                editor,
                                openedAtMs: sess.openedAtMs,
                                closedAtMs,
                                durationSeconds,
                            });
                            await (0, firebaseRest_1.firestoreCreateSessionLog)({
                                projectId,
                                documentId: docId,
                                accessToken: access,
                                payload: body,
                            });
                            cloudOk = true;
                            tgIdeLog(`Firestore: gravado · ${sess.countingLabel} · ${durationSeconds}s · dia=${workDateLocal} · doc=${docId}`);
                        }
                        catch (e) {
                            errorMsg = e instanceof Error ? e.message : String(e);
                            tgIdeLog(`Firestore FALHOU: ${errorMsg}`);
                        }
                    }
                    else {
                        errorMsg = 'sem login Firebase (comando «iniciar sessão Firebase»)';
                        tgIdeLog(`Firestore: ${errorMsg}`);
                    }
                }
                statusHandle.dispose();
                const durStr = (0, localLog_1.formatDurationHumanPt)(durationSeconds);
                if (cloudOk) {
                    void vscode.window.showInformationMessage(`TG Work ✓ Gravado: "${sess.countingLabel}" · ${durStr} · ${workDateLocal}`, 'Ver Saída').then((pick) => {
                        if (pick === 'Ver Saída') {
                            tgIdeLogChannel?.show(true);
                        }
                    });
                }
                else if (syncCloud) {
                    void vscode.window.showWarningMessage(`TG Work: PC gravado, Firestore falhou: ${errorMsg}`, 'Ver Saída').then((pick) => {
                        if (pick === 'Ver Saída') {
                            tgIdeLogChannel?.show(true);
                        }
                    });
                }
                else {
                    void vscode.window.showInformationMessage(`TG Work: "${sess.countingLabel}" · ${durStr} · gravado no PC (sync nuvem desligado).`);
                }
            }
        }
        catch (e) {
            statusHandle.dispose();
            void vscode.window.showErrorMessage(`TG Work: erro ao gravar: ${e instanceof Error ? e.message : String(e)}`);
        }
        await startOrRefreshSession(context);
    }));
    context.subscriptions.push(vscode.commands.registerCommand('tgWorkIde.openLocalLogs', async () => {
        const dir = path.dirname((0, localLog_1.localIdeSessionsFilePath)());
        await vscode.env.openExternal(vscode.Uri.file(dir));
    }));
    context.subscriptions.push(vscode.commands.registerCommand('tgWorkIde.firebaseLoginHelp', async () => {
        const mdPath = path.join(context.extensionPath, 'FIREBASE_LOGIN.md');
        const uri = vscode.Uri.file(mdPath);
        const open = await vscode.window.showWarningMessage('A TG Work IDE usa apenas Email + palavra‑passe Firebase (não há «Continuar com Google» aqui).', 'Abrir FIREBASE_LOGIN.md', 'Fechar');
        if (open === 'Abrir FIREBASE_LOGIN.md') {
            try {
                const doc = await vscode.workspace.openTextDocument(uri);
                await vscode.window.showTextDocument(doc, { preview: true });
            }
            catch {
                void vscode.window.showErrorMessage(`Não encontrei o ficheiro: ${mdPath}`);
            }
        }
    }));
    context.subscriptions.push(vscode.commands.registerCommand('tgWorkIde.signIn', async () => {
        const apiKey = cfg().get('firebaseApiKey') ?? '';
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
            const r = await (0, firebaseRest_1.signInWithPassword)(apiKey, emailTrim, password);
            await context.secrets.store(SECRET_REFRESH, r.refreshToken);
            await context.secrets.store(SECRET_UID, r.localId);
            void vscode.window.showInformationMessage('TG Work IDE: sessão Firebase iniciada.');
        }
        catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            const pick = await vscode.window.showErrorMessage(msg, 'Ajuda login Firebase…');
            if (pick === 'Ajuda login Firebase…') {
                await vscode.commands.executeCommand('tgWorkIde.firebaseLoginHelp');
            }
        }
    }));
    context.subscriptions.push(vscode.commands.registerCommand('tgWorkIde.signOut', async () => {
        await context.secrets.delete(SECRET_REFRESH);
        await context.secrets.delete(SECRET_UID);
        tgFirestoreResolveMemo = undefined;
        (0, firebaseRest_1.clearAccessTokenCache)();
        void vscode.window.showInformationMessage('TG Work IDE: sessão Firebase terminada.');
    }));
    context.subscriptions.push(vscode.workspace.onDidChangeConfiguration((e) => {
        if (e.affectsConfiguration('tgWorkIde.countingFolderFsPath') ||
            e.affectsConfiguration('tgWorkIde.syncToFirestore') ||
            e.affectsConfiguration('tgWorkIde.autoResolveFirestoreProject') ||
            e.affectsConfiguration('tgWorkIde.minSessionSeconds') ||
            e.affectsConfiguration('tgWorkIde.onlyShortcutWorkspace')) {
            void startOrRefreshSession(context).catch(() => undefined);
        }
    }));
    await workspaceFoldersChanged();
    setTimeout(() => void workspaceFoldersChanged(), 750);
    installHostLifecycleFlushOnce(context);
}
async function deactivate() {
    stopHeartbeat();
    stopTokenRefreshTimer();
    disposeSessionStatusTicker();
    const ctx = extensionContext;
    if (current && ctx) {
        // Aviso visual imediato — o utilizador vê que algo está a acontecer
        void vscode.window.setStatusBarMessage('$(sync~spin) TG Work: a gravar sessão...', 10000);
    }
    try {
        await finalizeCurrent(ctx, Date.now(), false, 'fecho-janela');
    }
    catch {
        //
    }
    extensionContext = undefined;
}
//# sourceMappingURL=extension.js.map