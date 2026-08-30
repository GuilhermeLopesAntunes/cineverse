import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { db } from '../../prisma/db';
import { ChatRoomType, CreateChatRoomDto } from './dto/create-chat-room.dto';

export interface ChatRoomResponse {
  id: number;
  type: ChatRoomType;
  createdAt: string;
}

export interface MessageResponse {
  id: number;
  roomId: number;
  senderId: number;
  content: string;
  createdAt: string;
}

export interface Paginated<T> {
  items: T[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

const ROOM_FIELDS = ['id', 'type', 'createdAt'] as const;
const MESSAGE_FIELDS = [
  'id',
  'roomId',
  'senderId',
  'content',
  'createdAt',
] as const;

@Injectable()
export class ChatService {
  // Individual rooms always have exactly 2 members by construction (the
  // check below is the only place a room's members are set at creation) —
  // no need to re-verify member count when looking one up.
  async createRoom(
    currentUserId: number,
    dto: CreateChatRoomDto,
  ): Promise<ChatRoomResponse> {
    const memberIds = Array.from(new Set([currentUserId, ...dto.memberIds]));

    if (dto.type === 'individual') {
      if (memberIds.length !== 2) {
        throw new BadRequestException(
          'Chat individual precisa de exatamente 2 participantes',
        );
      }
      const [userA, userB] = memberIds;
      const existing = await this.findExistingIndividualRoom(userA, userB);
      if (existing) {
        return existing;
      }
    }

    await this.assertUsersExist(memberIds);

    return db.transaction(async (tx) => {
      const room = await tx.orm.public.ChatRoom.select(...ROOM_FIELDS).create({
        type: dto.type,
      });
      for (const userId of memberIds) {
        await tx.orm.public.ChatRoomMember.create({ roomId: room.id, userId });
      }
      return room as ChatRoomResponse;
    });
  }

  // Ordered by id desc as a stable proxy for "most recently created" —
  // sorting by last-activity would need a join against Message and isn't
  // needed yet for a chat list to be usable.
  async listRooms(
    userId: number,
    page: number,
    pageSize: number,
  ): Promise<Paginated<ChatRoomResponse>> {
    const memberships = await db.orm.public.ChatRoomMember.where({
      userId,
    })
      .select('roomId')
      .all();
    const roomIds = memberships.map((m) => m.roomId);

    if (roomIds.length === 0) {
      return { items: [], page, pageSize, total: 0, totalPages: 1 };
    }

    const offset = (page - 1) * pageSize;
    const items = await db.orm.public.ChatRoom.where((r) => r.id.in(roomIds))
      .select(...ROOM_FIELDS)
      .orderBy((r) => r.id.desc())
      .offset(offset)
      .limit(pageSize)
      .all();

    const total = roomIds.length;
    return {
      items: items as ChatRoomResponse[],
      page,
      pageSize,
      total,
      totalPages: Math.max(1, Math.ceil(total / pageSize)),
    };
  }

  // Newest first, same convention as the review feed (BE-15) — the client
  // reverses for display, which also means "page 1" is always the most
  // recent slice of an ever-growing history.
  async listMessages(
    roomId: number,
    userId: number,
    page: number,
    pageSize: number,
  ): Promise<Paginated<MessageResponse>> {
    await this.assertMember(roomId, userId);

    const offset = (page - 1) * pageSize;
    const [items, { total }] = await Promise.all([
      db.orm.public.Message.where({ roomId })
        .select(...MESSAGE_FIELDS)
        .orderBy((m) => m.createdAt.desc())
        .offset(offset)
        .limit(pageSize)
        .all(),
      db.orm.public.Message.where({ roomId }).aggregate((aggregate) => ({
        total: aggregate.count(),
      })),
    ]);

    return {
      items,
      page,
      pageSize,
      total,
      totalPages: Math.max(1, Math.ceil(total / pageSize)),
    };
  }

  async createMessage(
    roomId: number,
    senderId: number,
    content: string,
  ): Promise<MessageResponse> {
    await this.assertMember(roomId, senderId);
    return db.orm.public.Message.select(...MESSAGE_FIELDS).create({
      roomId,
      senderId,
      content,
    });
  }

  // Used by the /chat gateway too (BE-19) — a socket has no HTTP guard to
  // rely on, so every join/send goes through this same check.
  async assertMember(roomId: number, userId: number): Promise<void> {
    const room = await db.orm.public.ChatRoom.where({ id: roomId }).first();
    if (!room) {
      throw new NotFoundException(`Sala de chat ${roomId} não encontrada`);
    }
    const membership = await db.orm.public.ChatRoomMember.where({
      roomId,
      userId,
    }).first();
    if (!membership) {
      throw new ForbiddenException('Você não participa dessa sala de chat');
    }
  }

  private async findExistingIndividualRoom(
    userA: number,
    userB: number,
  ): Promise<ChatRoomResponse | null> {
    const roomsForA = await db.orm.public.ChatRoomMember.where({
      userId: userA,
    })
      .select('roomId')
      .all();
    const roomIdsForA = roomsForA.map((m) => m.roomId);
    if (roomIdsForA.length === 0) {
      return null;
    }

    const shared = await db.orm.public.ChatRoomMember.where((m) =>
      m.roomId.in(roomIdsForA),
    )
      .where({ userId: userB })
      .select('roomId')
      .all();

    for (const { roomId } of shared) {
      const room = await db.orm.public.ChatRoom.where({
        id: roomId,
        type: 'individual',
      })
        .select(...ROOM_FIELDS)
        .first();
      if (room) {
        return room as ChatRoomResponse;
      }
    }
    return null;
  }

  private async assertUsersExist(userIds: number[]): Promise<void> {
    const users = await db.orm.public.User.where((u) => u.id.in(userIds))
      .select('id')
      .all();
    const foundIds = new Set(users.map((u) => u.id));
    const missing = userIds.filter((id) => !foundIds.has(id));
    if (missing.length > 0) {
      throw new NotFoundException(
        `Usuário(s) não encontrado(s): ${missing.join(', ')}`,
      );
    }
  }
}
