import { IsInt, IsString, MaxLength, MinLength } from 'class-validator';

export class SendMessageDto {
  @IsInt()
  roomId!: number;

  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  content!: string;
}
