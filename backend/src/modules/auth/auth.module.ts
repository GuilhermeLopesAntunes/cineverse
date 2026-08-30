import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

@Module({
  // Empty options: secret/expiresIn are passed explicitly per sign/verify
  // call (see jwt.config.ts) since access and refresh tokens use different
  // secrets — there's no single sane module-wide default here.
  imports: [JwtModule.register({})],
  controllers: [AuthController],
  providers: [AuthService],
})
export class AuthModule {}
