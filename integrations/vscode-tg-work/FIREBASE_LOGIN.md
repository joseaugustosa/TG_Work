# TG Work IDE — Ligação ao Firebase (sessão + Agenda na app)

A extensão **não** usa «Continuar com Google». Só faz login com **Email + palavra-passe** (API oficial `signInWithPassword`).

## O comando não pede email / não aparece nada

1. **`Ctrl+Shift+P`** → escreve **`TG Work IDE: iniciar sessão Firebase`** (tem de ser este comando da extensão **TG Work IDE Session**, não login da conta Cursor).
2. O campo aparece na **barra rápida no topo** do Cursor/VS Code (título **TG Work IDE — Login Firebase**). Se clicares fora, o campo já **não** some só por perder foco.
3. **`Esc`** cancela — aparece mensagem «login cancelado». Se antes cancelavas à primeira, parecia que «não pedia» nada.

## Se na app TG Work entras só com Google

Precisas de uma **palavra-passe** ligada ao **mesmo email** para a extensão conseguir autenticar:

1. **Firebase Console** → **Authentication** → **Users**.
2. Encontra o teu utilizador pelo email ou cria conta com email se precisares.
3. Opções típicas:
   - Para utilizador já criado via Google: no separador Users, **`Add password`** / **«Redefinir palavra-passe»** (nome varia conforme a consola) para esse email; ou
   - **Sign-in method** → activa **Email/Password**.
4. Define uma palavra-passe forte e usa **exactamente esse email + palavra-passe** no comando **`TG Work IDE: iniciar sessão Firebase`** no VS Code / Cursor.

O **UID da conta deve ser o mesmo** (mesmo utilizador Firebase) para a Agenda IDE na app e as sessões da extensão bater certo.

## API Key (`tgWorkIde.firebaseApiKey`)

Tem de ser a mesma dos alvos **Web** ou **Windows** em `tg_work/lib/firebase_options.dart` (`AIza…` igual à extensão por defeito). **Não** uses a chave só-Android dessa página.

No **Google Cloud Console**, se aplicaste **Restrições** à Web API Key, garante permissão para **Identity Toolkit API** / pedidos necessários ao login (chaves fortemente restritas podem falhar).

## Ligação ao Firestore (Agenda)

### Como funciona (importante)

- Com **sync + login Firebase**, ao **abrir** o workspace a extensão cria um documento em **`user_ide_session_logs`** com **`openedAt`** e **`durationSeconds` = 0** (marcador de início).
- Ao **fechar** a janela ou usar **TG Work IDE: gravar sessão agora**, faz-se **PATCH** ao mesmo documento: **`closedAt`** e **`durationSeconds`** finais.
- **Requisito obrigatório:** as **Firestore Security Rules** no projeto têm de permitir este **PATCH** (o repo TG Work já inclui `allow update` em `user_ide_session_logs`). Depois de actualizar `tg_work/firestore.rules`, faz **`firebase deploy --only firestore:rules`** (ou deploy completo Firestore).
- O ficheiro local **`sessions.jsonl`** só recebe linha se a duração for **≥ `tgWorkIde.minSessionSeconds`** (por defeito 30 s); no Firestore o PATCH corre **sempre** que existir documento stub, mesmo para segmentos curtos.

1. **`tgWorkIde.syncToFirestore`** = verdadeiro.

2. **Login Firebase** na extensão (comando acima) com êxito → tens token guardado pelo VS Code/Cursor.

3. Usa **TG Work IDE: abrir registo de diagnóstico** — ao **abrir** o workspace deves ver `Firestore: INÍCIO gravado · doc=...`; ao **fechar** ou «gravar sessão agora», `Firestore: FIM gravado (PATCH) · doc=...` ou o erro exacto.

4. Na **Firebase Console** → Firestore → **`user_ide_session_logs`** deves ver um documento **logo ao abrir** o workspace (com `durationSeconds` 0 até fechares); na **Agenda TG Work** só aparecem sessões com **`durationSeconds` > 0** (depois do fecho).

## Mensagens típicas de erro

- **`OPERATION_NOT_ALLOWED`** — Activa Email/Password em Authentication → Sign-in method.
- **`INVALID_LOGIN_CREDENTIALS`** — Email/pass errados ou ainda só tens conta Google sem palavra-passe Firebase.
- **`API_KEY_INVALID` / restrita** — Troca/restaura API key compatível Identity Toolkit.

