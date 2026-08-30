interface SqlUniqueViolation {
  sqlState: '23505';
}

// Postgres unique-constraint violation, as it actually arrives from this
// Prisma Next target — not a PN-* code, not a Nest exception. See
// CLAUDE.md's Convenções section for where this was first worked out.
export function isUniqueViolation(err: unknown): err is SqlUniqueViolation {
  return (
    typeof err === 'object' &&
    err !== null &&
    'sqlState' in err &&
    (err as { sqlState?: unknown }).sqlState === '23505'
  );
}
