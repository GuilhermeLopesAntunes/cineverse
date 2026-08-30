import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsIn,
  IsInt,
} from 'class-validator';

export type ChatRoomType = 'individual' | 'group';

export class CreateChatRoomDto {
  @IsIn(['individual', 'group'])
  type!: ChatRoomType;

  // The other participant(s) — the caller is added automatically, so this
  // never needs to (and shouldn't) include their own id.
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @ArrayUnique()
  @IsInt({ each: true })
  memberIds!: number[];
}
