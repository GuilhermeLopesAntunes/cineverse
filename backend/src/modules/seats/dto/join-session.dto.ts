import { IsInt } from 'class-validator';

export class JoinSessionDto {
  @IsInt()
  sessionId!: number;
}
