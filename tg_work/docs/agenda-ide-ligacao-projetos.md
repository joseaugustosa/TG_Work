# Agenda IDE → aba Projetos

## Comportamento

Com sessão Firebase activa, a app mantém a coleção `projects` alinhada com a Agenda IDE:

1. **Sessões sem `tgProjectId`** (`ws:workspace`) → cria projeto e tenta gravar o ID na sessão.
2. **Sessões com `tgProjectId` órfão** (ID na nuvem mas documento `projects` em falta) → restaura o documento com o **mesmo ID** (extensão VS Code/Cursor continua válida).
3. **Cartões Kanban** (`user_ide_schedule/.../cards`) com chave `ws:` ou `tg:` sem projeto → idem.

Sincronização global: `IdeAgendaProjectsLinkHost` em `home_shell_screen.dart`. Reconcile do Kanban IDE chama a mesma lógica.

## Firestore

- Regras: `tg_work/firestore.rules` — permite actualizar `tgProjectId` de `""` para um ID válido em `user_ide_session_logs`.
- Deploy: `firebase deploy --only firestore:rules` (directório `tg_work`).

## Build Windows

```powershell
cd tg_work
flutter build windows
# Executável: build\windows\x64\runner\Release\tg_work.exe
```

## Workspace Cursor / VS Code

- Ficheiro multi-root: `TG_Work.code-workspace` (raiz, `tg_work`, extensão IDE).
- Ligação local: `.tgwork/project.json` na raiz do repositório.
- Atalho ambiente de trabalho: `powershell -ExecutionPolicy Bypass -File scripts/atualiza-atalho-tg-work.ps1` (abre só este workspace no Cursor).
- **Commit automatico**: hook Cursor `stop` → `.cursor/hooks/auto-commit.ps1` (local, sem push). Config em `.cursor/hooks.json`.

Histórico de implementação: conversa Cursor «agenda IDE → aba projetos» (Jun 2026).
