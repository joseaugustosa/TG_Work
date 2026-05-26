# TG Work — extensão VS Code / Cursor

### O que isto faz (modelo simples)

- **Um pacote** (`*.vsix`) instala-se igual no **VS Code** e no **Cursor** — a contagem é a mesma.
- **Por projeto TG Work** acumulas **tempo efectivo** enquanto tens a janela aberta nesse workspace (até fechares ou mudares de pasta/workspace).
- **Sessão** = um segmento gravado (uma linha no `sessions.jsonl` no PC; na nuvem, um doc com abertura → fecho).
- **Dias** = dias de calendário locais em que houve pelo menos uma sessão (vês isso no relatório da app **Agenda IDE → Relatório por projeto** e na saída **«totais… (PC)»** da extensão).

Tempo conta **automaticamente** quando há pastas no workspace até **fechares a janela** ou mudares de projeto/pasta de contagem.

- **Por defeito (`tgWorkIde.onlyShortcutWorkspace` = false)** conta também com **Open Folder**. Se quiseres **só** atalhos `.code-workspace` / `.cursor-workspace`, define **`tgWorkIde.onlyShortcutWorkspace`: true** nas settings.

- **Início / fim:** ao arrancar aparece **Sessão INÍCIO** no painel **Saída → TG Work IDE**; ao fechar aparece linha sobre gravação ou **abaixo do mínimo de segundos** (`tgWorkIde.minSessionSeconds`, defeito 30s — sessões mais curtas não vão para `sessions.jsonl`).
- **Barra de estado:** ícone **TG Work · nome da pasta · tempo decorrido** — actualiza automaticamente (clique para ver totais por projeto).
- **Uma linha por sessão fechada** no ficheiro local. No **mesmo dia** aparecem **várias linhas** se abrires e fechares o VS Code ou o Cursor várias vezes.
- Cada linha inclui **`workDateLocal`** (`aaaa-mm-dd`), **`openedAt`**, **`closedAt`**, **`durationSeconds`**, **`workspaceShortcut`** (caminho do `.code-workspace`) ou **`workspaceMode: folder`**.

Por defeito **só no PC**:

- **Windows:** `%LOCALAPPDATA%\TG Work\ide-sessions\sessions.jsonl`

Comando **«TG Work IDE: abrir pasta dos registos (PC)»**.

**Opcional Firebase (recomendado para a Agenda TG Work):** settings **`tgWorkIde.syncToFirestore`** (por defeito **ligado** na versão actual) + **«TG Work IDE: iniciar sessão Firebase»** com a mesma conta que na app. Sem isto as sessões ficam apenas no PC (`sessions.jsonl`) e não aparecem na app.

A extensão **só** aceita **email + palavra‑passe** (não abre página Google). Ver o guia **`FIREBASE_LOGIN.md`** na pasta da extensão e o comando **TG Work IDE: ajuda login Firebase…**.

### Erro «Npm task detection: failed to parse … package.json» (VS Code / Cursor)

No **VS Code** ou **Cursor** este texto pode ser **enganador**: costuma aparecer quando o IDE **não consegue ler o ficheiro a tempo** (corrida ao abrir o manifest), não porque o JSON esteja inválido — ver [relato no fórum Cursor](https://forum.cursor.com/t/bug-report-2-npm-task-detection-fails-to-parse-valid-package-json/161125).

**Correcção aplicada neste repo**

- Raiz **TG_Work**: `.vscode/settings.json` com **`npm.autoDetect`: `off`** (só há este `package.json` JavaScript no repo; continuas a usar **`npm run compile`** no terminal).
- **Só** a pasta da extensão: `integrations/vscode-tg-work/.vscode/settings.json` também desliga a detecção automática.

Se abrires outro workspace à parte, nas **User Settings** do **VS Code** ou **Cursor** (`Ctrl+,` → ícone JSON) podes usar **`npm.autoDetect`: `off`** ou **`npm.exclude`** para esta pasta.

Android Studio não coberto (plugin IntelliJ).

## Instalar (desenvolvimento)

```bash
npm install && npm run compile
```

Ou **Developer: Install Extension from Location…** nesta pasta.

## Instalar no VS Code (mesmo pacote que no Cursor)

O ficheiro **`tg-work-ide-session-<versão>.vsix`** na pasta desta extensão instala-se igual nos dois editores.

**Linha de comandos (Windows), na pasta da extensão:**

```powershell
code --install-extension .\tg-work-ide-session-0.2.3.vsix --force
```

Se `code` não for reconhecido, usa o caminho típico:

```powershell
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --install-extension .\tg-work-ide-session-0.2.3.vsix --force
```

**Ou pela UI:** VS Code → **Extensions** (`Ctrl+Shift+X`) → menu **⋯** → **Install from VSIX…** → escolhe o `.vsix`.

Na raiz do repo TG_Work, o script **`scripts/apply-tg-work-ide-session.ps1`** também configura **VS Code Stable**, **VS Code Insiders** e **Cursor** (settings + instalação do VSIX quando encontra os CLIs).

Depois de instalar: **Reload Window** e **`TG Work IDE: iniciar sessão Firebase`** (igual ao Cursor).

## Configuração mínima

Sem login no IDE. **Com sessão Firebase** (`TG Work IDE: iniciar sessão…`): o projecto associa‑se normalmente **sozinho** — a extensão consulta Firestore (`projects`): primeiro por **`ideCountingFolderFsPath`** igual à pasta atual / ficheiro `*.code-workspace`, e se falhar pela **similaridade entre o nome da pasta e o nome do projecto TG Work** (só quando essa equivalência é **única**, para não errar).

Opcional mantém‑se um **`.tgwork/project.json`** (`example-project-tg-work.json`) com **`tgWorkProjectId`** quando quiseres forçar o ID sem depender do Firestore. Podes desligar inferência nas settings **`tgWorkIde.autoResolveFirestoreProject`** (por defeito activa).

## Pasta de projeto para contar (várias raízes ou `.code-workspace`)

Por defeito usa a **primeira pasta raiz**.

- **Paleta:** `TG Work IDE: escolher pasta para contagem de tempo` → escolhe qual raiz conta para o tempo, `.tgwork` e o nome no registo. Mudar a escolha **reinicia** a sessão de tempo.
- **`.tgwork/project.json`:** campo **`ideCountingFolderFsPath`** (opcional) — mesmo significado que na app TG Work; **antecede** a escolha da paleta mas **é ultrapassado** por settings (mantém comandos sobretaxa para esse PC).
- **Settings (por janela):** `tgWorkIde.countingFolderFsPath` = caminho absoluto de uma das pastas raiz.

## Comandos

- **TG Work IDE: ajuda login Firebase…** — abre o guia (Google VS email/palavra‑passe, API Key, erros típicos).

- **TG Work IDE: tempo, sessões e dias por projeto (PC)…** — soma `sessions.jsonl`: tempo e **sessões**, **dias distintos** por projeto TG (ou pasta) no registo TG Work IDE.

- **TG Work IDE: gravar sessão agora** — grava o segmento e **volta** a contar desde já no mesmo workspace.
