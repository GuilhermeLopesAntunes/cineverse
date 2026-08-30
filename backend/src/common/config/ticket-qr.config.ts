export interface TicketQrConfig {
  secret: string;
}

// Separate from jwt.config.ts's access/refresh secrets on purpose — a
// ticket QR has nothing to do with a user's login session (it isn't even
// tied to a signed-in request at validation time, BE-33), so it gets its
// own secret rather than reusing one meant for auth tokens.
export const ticketQrConfig: TicketQrConfig = {
  secret: process.env.TICKET_QR_SECRET!,
};
