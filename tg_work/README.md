# tg_work

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the


## Agenda IDE & tempo nos editores VS Code/Cursor

- Na app aparece uma nova zona **«Agenda IDE»** (Kanban dedicado mais histórico de sessões vindas das IDEs).

- Para contar tempo ao **abrir/fechar workspace** num editor compatível, instala a extensão em  
  **`integrations/vscode-tg-work/`** (instruções no respetivo README): login Firebase igual ao da app + ficheiro **`.tgwork/project.json`** na raiz da pasta git com `tgWorkProjectId`.

**Importante:** faz deploy das regras e índices Firestore atualizados (`firebase.json` na pasta `tg_work`):  
`firestore.rules` e **`firestore.indexes.json`** (índice composto em `user_ide_session_logs`).

O **Android Studio** não é coberto pela mesma extensão; só editores tipo VS Code.