"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.describeIdentityToolkitLoginFailure = describeIdentityToolkitLoginFailure;
exports.summarizeIdentityToolkitErrorBody = summarizeIdentityToolkitErrorBody;
/** Traduz códigos comuns do Identity Toolkit (signInWithPassword) para português. */
function describeIdentityToolkitLoginFailure(rawMessage) {
    const m = String(rawMessage ?? '')
        .trim()
        .replace(/^auth\//i, '');
    const detail = `Código devolvido: ${rawMessage || '(vazio)'}`;
    const map = {
        INVALID_LOGIN_CREDENTIALS: 'Email ou palavra-passe incorretos. Se só usas «Entrar com Google» na app TG Work, vê o guia de login (comando de ajuda na extensão): precisas de Email/palavra-passe no Firebase ou de definir uma palavra-passe para o mesmo email.',
        INVALID_PASSWORD: 'Palavra-passe incorreta.',
        EMAIL_NOT_FOUND: 'Não há utilizador Firebase com esse email.',
        USER_NOT_FOUND: 'Não há utilizador Firebase com esse email.',
        USER_DISABLED: 'Esta conta foi desactivada.',
        TOO_MANY_ATTEMPTS_TRY_LATER: 'Muitas tentativas falhadas — tenta mais tarde ou redefine a palavra-passe na consola Firebase.',
        OPERATION_NOT_ALLOWED: 'Método Email/palavra-passe não está activo no Firebase Authentication. Liga-o na consola: Authentication → Sign-in method → Email/Password.',
        API_KEY_INVALID: 'API Key inválida (tgWorkIde.firebaseApiKey). Usa a mesma «Web» / Windows da `firebase_options.dart` do projecto tg_work, não a chave só-Android.',
        INVALID_API_KEY: 'API Key inválida ou restrita no Google Cloud. Verifica restricções da chave (deve poder usar Identity Toolkit / Firestore REST).',
        NETWORK_REQUEST_FAILED: 'Pedido falhou por rede ou firewall corporativo ao identitytoolkit.googleapis.com.',
        INVALID_EMAIL: 'Formato de email inválido.',
    };
    const friendly = map[m];
    return friendly ? `${friendly}\n\n${detail}` : `${detail}\n\n(Se continuares sem perceber, corre o comando de ajuda TG Work IDE na paleta.)`;
}
function summarizeIdentityToolkitErrorBody(bodyUnknown, httpStatusText) {
    if (!bodyUnknown || typeof bodyUnknown !== 'object') {
        return describeIdentityToolkitLoginFailure('');
    }
    const j = bodyUnknown;
    /** Formato GCP: `{ error: { message: string, ... } }` ou `{ error: "string" }` */
    let raw = '';
    const err = j['error'];
    if (typeof err === 'string') {
        raw = err;
    }
    else if (typeof err === 'object' && err !== null && 'message' in err) {
        raw = String(err.message ?? '');
    }
    if (!raw && typeof j['message'] === 'string') {
        raw = j['message'];
    }
    if (!raw) {
        try {
            raw = JSON.stringify(j);
        }
        catch {
            raw = httpStatusText;
        }
    }
    return describeIdentityToolkitLoginFailure(raw);
}
//# sourceMappingURL=firebaseAuthErrors.js.map