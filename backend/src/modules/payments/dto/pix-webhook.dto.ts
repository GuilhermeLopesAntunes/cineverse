import { IsIn, IsString } from 'class-validator';

// Shape of what a real Pix provider's webhook call would deliver —
// `providerRef` correlates back to the Payment this app created (BE-27);
// `status` is the terminal outcome the provider is reporting.
export class PixWebhookDto {
  @IsString()
  providerRef!: string;

  @IsIn(['paid', 'failed'])
  status!: 'paid' | 'failed';
}
