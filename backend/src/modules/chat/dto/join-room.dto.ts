import { IsInt } from 'class-validator';

export class JoinRoomDto {
  @IsInt()
  roomId!: number;
}
