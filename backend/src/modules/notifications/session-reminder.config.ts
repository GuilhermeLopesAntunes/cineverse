export interface SessionReminderConfig {
  // How long before a purchased session's start time the reminder fires —
  // RF-17 doesn't pin an exact lead time, so this is a configurable
  // default rather than a hardcoded guess.
  hoursBefore: number;
  // How often the job checks for due reminders. Independent of
  // `hoursBefore` — the window is wide, the check just needs to run often
  // enough that no due reminder is missed and no one gets notified late.
  intervalMs: number;
}

export const sessionReminderConfig: SessionReminderConfig = {
  hoursBefore: Number(process.env.SESSION_REMINDER_HOURS_BEFORE ?? 24),
  intervalMs: Number(
    process.env.SESSION_REMINDER_INTERVAL_MS ?? 15 * 60 * 1000,
  ),
};
