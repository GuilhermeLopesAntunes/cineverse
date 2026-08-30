import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { db } from '../../prisma/db';
import { ChatService } from './chat.service';

interface Chain {
  where: jest.Mock;
  select: jest.Mock;
  orderBy: jest.Mock;
  offset: jest.Mock;
  limit: jest.Mock;
  first: jest.Mock;
  all: jest.Mock;
  aggregate: jest.Mock;
}

function makeChain(): Chain {
  const chain = {} as Chain;
  chain.where = jest.fn().mockReturnValue(chain);
  chain.select = jest.fn().mockReturnValue(chain);
  chain.orderBy = jest.fn().mockReturnValue(chain);
  chain.offset = jest.fn().mockReturnValue(chain);
  chain.limit = jest.fn().mockReturnValue(chain);
  chain.first = jest.fn();
  chain.all = jest.fn().mockResolvedValue([]);
  chain.aggregate = jest.fn().mockResolvedValue({ total: 0 });
  return chain;
}

interface FakeTx {
  orm: {
    public: {
      ChatRoom: { select: jest.Mock };
      ChatRoomMember: { create: jest.Mock };
    };
  };
}

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        ChatRoom: {},
        ChatRoomMember: {},
        Message: {},
        User: {},
      },
    },
    transaction: jest.fn(),
  },
}));

describe('ChatService', () => {
  let service: ChatService;
  let chatRoomChain: Chain;
  let chatRoomWhereMock: jest.Mock;
  let chatRoomMemberChain: Chain;
  let messageChain: Chain;
  let userChain: Chain;
  let transactionMock: jest.Mock;
  let roomCreateMock: jest.Mock;
  let memberCreateMock: jest.Mock;

  const sampleRoom = { id: 1, type: 'group', createdAt: 'now' };
  const sampleMessage = {
    id: 1,
    roomId: 1,
    senderId: 1,
    content: 'oi',
    createdAt: 'now',
  };

  beforeEach(() => {
    service = new ChatService();

    chatRoomChain = makeChain();
    chatRoomChain.first.mockResolvedValue(sampleRoom);

    chatRoomMemberChain = makeChain();
    chatRoomMemberChain.first.mockResolvedValue({ roomId: 1, userId: 1 });

    messageChain = makeChain();
    userChain = makeChain();
    userChain.all.mockResolvedValue([{ id: 1 }, { id: 2 }, { id: 3 }]);

    chatRoomWhereMock = jest.fn().mockReturnValue(chatRoomChain);
    (db.orm.public.ChatRoom as unknown as { where: jest.Mock }).where =
      chatRoomWhereMock;
    (db.orm.public.ChatRoomMember as unknown as { where: jest.Mock }).where =
      jest.fn().mockReturnValue(chatRoomMemberChain);
    (db.orm.public.Message as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(messageChain);
    (db.orm.public.User as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(userChain);

    roomCreateMock = jest.fn().mockResolvedValue(sampleRoom);
    memberCreateMock = jest.fn().mockResolvedValue(undefined);
    transactionMock = jest
      .fn()
      .mockImplementation(
        async (callback: (tx: FakeTx) => Promise<unknown>) => {
          const tx: FakeTx = {
            orm: {
              public: {
                ChatRoom: {
                  select: jest.fn().mockReturnValue({ create: roomCreateMock }),
                },
                ChatRoomMember: { create: memberCreateMock },
              },
            },
          };
          return callback(tx);
        },
      );
    (db.transaction as unknown as jest.Mock) = transactionMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('createRoom', () => {
    it('creates a group room with the caller plus every member', async () => {
      const result = await service.createRoom(1, {
        type: 'group',
        memberIds: [2, 3],
      });

      expect(userChain.all).toHaveBeenCalled();
      expect(roomCreateMock).toHaveBeenCalledWith({ type: 'group' });
      expect(memberCreateMock).toHaveBeenCalledTimes(3);
      expect(result).toEqual(sampleRoom);
    });

    it('rejects an individual room with more than one other member', async () => {
      await expect(
        service.createRoom(1, { type: 'individual', memberIds: [2, 3] }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(transactionMock).not.toHaveBeenCalled();
    });

    it('returns an existing individual room instead of creating a duplicate', async () => {
      chatRoomMemberChain.all
        .mockResolvedValueOnce([{ roomId: 5 }]) // rooms userA belongs to
        .mockResolvedValueOnce([{ roomId: 5 }]); // shared with userB
      chatRoomChain.first.mockResolvedValueOnce({
        id: 5,
        type: 'individual',
        createdAt: 'now',
      });

      const result = await service.createRoom(1, {
        type: 'individual',
        memberIds: [2],
      });

      expect(result).toEqual({ id: 5, type: 'individual', createdAt: 'now' });
      expect(transactionMock).not.toHaveBeenCalled();
    });

    it('creates a new individual room when none exists yet', async () => {
      chatRoomMemberChain.all.mockResolvedValueOnce([]); // userA has no rooms at all

      await service.createRoom(1, { type: 'individual', memberIds: [2] });

      expect(transactionMock).toHaveBeenCalled();
      expect(memberCreateMock).toHaveBeenCalledTimes(2);
    });

    it('throws NotFoundException when a member id does not exist', async () => {
      userChain.all.mockResolvedValue([{ id: 2 }]); // 3 is missing

      await expect(
        service.createRoom(1, { type: 'group', memberIds: [2, 3] }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(transactionMock).not.toHaveBeenCalled();
    });
  });

  describe('listRooms', () => {
    it('returns an empty page without querying ChatRoom when the user has no rooms', async () => {
      chatRoomMemberChain.all.mockResolvedValue([]);

      const result = await service.listRooms(1, 1, 20);

      expect(result).toEqual({
        items: [],
        page: 1,
        pageSize: 20,
        total: 0,
        totalPages: 1,
      });
      expect(chatRoomWhereMock).not.toHaveBeenCalled();
    });

    it('lists rooms the user belongs to', async () => {
      chatRoomMemberChain.all.mockResolvedValue([{ roomId: 1 }, { roomId: 2 }]);
      chatRoomChain.all.mockResolvedValue([sampleRoom]);

      const result = await service.listRooms(1, 1, 20);

      expect(result.items).toEqual([sampleRoom]);
      expect(result.total).toBe(2);
    });
  });

  describe('assertMember', () => {
    it('throws NotFoundException when the room does not exist', async () => {
      chatRoomChain.first.mockResolvedValue(undefined);

      await expect(service.assertMember(999, 1)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('throws ForbiddenException when the user is not a member', async () => {
      chatRoomMemberChain.first.mockResolvedValue(undefined);

      await expect(service.assertMember(1, 999)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('resolves when the room exists and the user is a member', async () => {
      await expect(service.assertMember(1, 1)).resolves.toBeUndefined();
    });
  });

  describe('createMessage', () => {
    it('checks membership before persisting the message', async () => {
      (db.orm.public.Message as unknown as { select: jest.Mock }).select = jest
        .fn()
        .mockReturnValue({
          create: jest.fn().mockResolvedValue(sampleMessage),
        });

      const result = await service.createMessage(1, 1, 'oi');

      expect(chatRoomMemberChain.first).toHaveBeenCalled();
      expect(result).toEqual(sampleMessage);
    });

    it('rejects a message from a non-member', async () => {
      chatRoomMemberChain.first.mockResolvedValue(undefined);

      await expect(service.createMessage(1, 999, 'oi')).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });
  });

  describe('listMessages', () => {
    it('checks membership, then returns paginated history newest-first', async () => {
      messageChain.all.mockResolvedValue([sampleMessage]);
      messageChain.aggregate.mockResolvedValue({ total: 1 });

      const result = await service.listMessages(1, 1, 1, 20);

      expect(chatRoomMemberChain.first).toHaveBeenCalled();
      expect(messageChain.orderBy).toHaveBeenCalled();
      expect(result).toEqual({
        items: [sampleMessage],
        page: 1,
        pageSize: 20,
        total: 1,
        totalPages: 1,
      });
    });

    it('rejects listing history for a non-member', async () => {
      chatRoomMemberChain.first.mockResolvedValue(undefined);

      await expect(service.listMessages(1, 999, 1, 20)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });
  });
});
