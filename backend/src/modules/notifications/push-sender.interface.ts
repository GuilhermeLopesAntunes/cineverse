// Abstraction over the actual push provider — FCM (ARQUITETURA_BACKEND.md §
// 7, "Notificações push": "FCM (cobre Android e iOS), compatível
// nativamente com Flutter"). No real Firebase project is available for the
// MVP (per the user, 2026-08-29: same "faça uma simulação interna" as
// payments) — `MockPushSender` is the only implementation for now; a real
// one (firebase-admin's messaging API) plugs in later behind this same
// interface without `SessionReminderService` having to change.

export interface PushSendResult {
  success: boolean;
}

export interface PushSender {
  send(token: string, title: string, body: string): Promise<PushSendResult>;
}

export const PUSH_SENDER = Symbol('PUSH_SENDER');
