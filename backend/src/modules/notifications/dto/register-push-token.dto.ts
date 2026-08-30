import { IsIn, IsString, MaxLength } from 'class-validator';

// Only "ios"/"android" — FCM is the chosen provider (ARQUITETURA_BACKEND.md
// § 7, "Notificações push") and the client is Flutter, no separate web
// push flow requested anywhere in the requirements.
export class RegisterPushTokenDto {
  @IsString()
  @MaxLength(4096) // FCM tokens are long opaque strings; generous cap, not a real limit
  token!: string;

  @IsIn(['ios', 'android'])
  platform!: 'ios' | 'android';
}
