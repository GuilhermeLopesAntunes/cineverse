import { IsInt } from 'class-validator';

// `orderId` is a bare number, not a real Order FK — there's no Order entity
// yet (that's BE-24/25). This endpoint exists to simulate a sale made
// outside the app entirely (the physical box office), so it accepts
// whatever identifier that other, not-yet-built system would use.
export class BoxOfficeSaleDto {
  @IsInt()
  orderId!: number;
}
