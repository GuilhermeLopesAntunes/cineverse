import { IsIn, IsString, ValidateIf } from 'class-validator';

// Apple Pay / Google Pay (BE-28) and card (BE-29) all require `token` — the
// opaque, client-side token the wallet SDK / Stripe-Elements-or-equivalent
// hands back after the user authorizes — there is no card-number/expiry/CVV
// field anywhere in this DTO, for any method, by design (RF-11, RF-12).
export class CreatePaymentDto {
  @IsIn(['pix', 'apple_pay', 'google_pay', 'card'])
  method!: 'pix' | 'apple_pay' | 'google_pay' | 'card';

  @ValidateIf((dto: CreatePaymentDto) => dto.method !== 'pix')
  @IsString()
  token?: string;
}
