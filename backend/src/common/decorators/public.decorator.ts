import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

// Marks a route (or a whole controller) as exempt from the global
// JwtAuthGuard — see src/common/guards/jwt-auth.guard.ts. Everything is
// protected by default; this is the explicit opt-out.
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
