import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Test } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { MatchesService } from './matches.service';

const USER_ANA = 'user-ana';
const USER_BRUNO = 'user-bruno';
const USER_CARLA = 'user-carla';
const MY_DOG_ID = 'aaaaaaaa-0000-4000-8000-000000000001';
const BRUNO_DOG_ID = 'bbbbbbbb-0000-4000-8000-000000000002';
const CARLA_DOG_ID = 'cccccccc-0000-4000-8000-000000000003';

const makeOwner = (id: string, name: string) => ({
  id,
  name,
  email: `${name.toLowerCase()}@demo.com`,
  passwordHash: 'hash',
  phone: null,
  bio: null,
  avatarUrl: null,
  city: null,
  latitude: null,
  longitude: null,
  createdAt: new Date(),
  updatedAt: new Date(),
});

const makeDog = (id: string, ownerId: string, name: string) => ({
  id,
  ownerId,
  name,
  breed: 'Golden Retriever',
  sex: 'MALE',
  birthDate: new Date('2021-03-10T00:00:00.000Z'),
  size: 'LARGE',
  intent: 'BOTH',
  bio: null,
  neutered: false,
  pedigree: false,
  active: true,
  socialWhatsapp: null,
  socialInstagram: null,
  socialPinterest: null,
  socialTelegram: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  photos: [],
  owner: makeOwner(ownerId, name),
});

type DogFixture = ReturnType<typeof makeDog>;

const makeMatch = (id: string, dogA: DogFixture, dogB: DogFixture) => ({
  id,
  dogAId: dogA.id,
  dogBId: dogB.id,
  createdAt: new Date(),
  dogA,
  dogB,
  messages: [],
});

describe('MatchesService', () => {
  let service: MatchesService;

  const prismaMock = {
    dog: { findUnique: jest.fn() },
    match: { findMany: jest.fn(), findUnique: jest.fn() },
    message: { groupBy: jest.fn(), updateMany: jest.fn() },
  };

  const myDog = makeDog(MY_DOG_ID, USER_ANA, 'Luna');
  const brunoDog = makeDog(BRUNO_DOG_ID, USER_BRUNO, 'Rex');
  const carlaDog = makeDog(CARLA_DOG_ID, USER_CARLA, 'Nina');
  const match1 = makeMatch('match-1', myDog, brunoDog);
  const match2 = makeMatch('match-2', myDog, carlaDog);

  beforeEach(async () => {
    jest.clearAllMocks();
    prismaMock.dog.findUnique.mockResolvedValue(myDog);
    prismaMock.match.findMany.mockResolvedValue([]);
    prismaMock.message.groupBy.mockResolvedValue([]);
    prismaMock.message.updateMany.mockResolvedValue({ count: 0 });

    const moduleRef = await Test.createTestingModule({
      providers: [
        MatchesService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: EventEmitter2, useValue: { emit: jest.fn() } },
      ],
    }).compile();

    service = moduleRef.get(MatchesService);
  });

  describe('list (unreadCount)', () => {
    it('aggregates unread counts for the whole page in a single groupBy (no N+1)', async () => {
      prismaMock.match.findMany.mockResolvedValue([match1, match2]);
      prismaMock.message.groupBy.mockResolvedValue([
        { matchId: 'match-1', _count: { _all: 2 } },
      ]);

      const result = await service.list(USER_ANA, MY_DOG_ID);

      expect(result).toHaveLength(2);
      expect(result[0].unreadCount).toBe(2);
      expect(result[1].unreadCount).toBe(0);
      expect(prismaMock.message.groupBy).toHaveBeenCalledTimes(1);
      const groupByArgs = (
        prismaMock.message.groupBy.mock.calls as unknown as [[unknown]]
      )[0][0];
      expect(groupByArgs).toEqual({
        by: ['matchId'],
        where: {
          matchId: { in: ['match-1', 'match-2'] },
          senderId: { not: USER_ANA },
          readAt: null,
        },
        _count: { _all: true },
      });
    });

    it('skips the aggregation entirely when there are no matches', async () => {
      const result = await service.list(USER_ANA, MY_DOG_ID);

      expect(result).toEqual([]);
      expect(prismaMock.message.groupBy).not.toHaveBeenCalled();
    });

    it('rejects listing for a dog the user does not own with 403', async () => {
      prismaMock.dog.findUnique.mockResolvedValue(brunoDog);

      await expect(service.list(USER_ANA, BRUNO_DOG_ID)).rejects.toThrow(
        ForbiddenException,
      );
      expect(prismaMock.match.findMany).not.toHaveBeenCalled();
    });

    it('rejects listing for an unknown dog with 404', async () => {
      prismaMock.dog.findUnique.mockResolvedValue(null);

      await expect(service.list(USER_ANA, MY_DOG_ID)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('markRead', () => {
    it("marks only the other participant's unread messages as read", async () => {
      prismaMock.match.findUnique.mockResolvedValue(match1);

      await service.markRead(USER_ANA, 'match-1');

      expect(prismaMock.message.updateMany).toHaveBeenCalledTimes(1);
      const updateArgs = (
        prismaMock.message.updateMany.mock.calls as unknown as [
          [{ where: unknown; data: { readAt: unknown } }],
        ]
      )[0][0];
      expect(updateArgs.where).toEqual({
        matchId: 'match-1',
        senderId: { not: USER_ANA },
        readAt: null,
      });
      expect(updateArgs.data.readAt).toBeInstanceOf(Date);
    });

    it('rejects a user outside the match with 403', async () => {
      prismaMock.match.findUnique.mockResolvedValue(match1);

      await expect(service.markRead(USER_CARLA, 'match-1')).rejects.toThrow(
        ForbiddenException,
      );
      expect(prismaMock.message.updateMany).not.toHaveBeenCalled();
    });

    it('rejects an unknown match with 404', async () => {
      prismaMock.match.findUnique.mockResolvedValue(null);

      await expect(service.markRead(USER_ANA, 'match-x')).rejects.toThrow(
        NotFoundException,
      );
      expect(prismaMock.message.updateMany).not.toHaveBeenCalled();
    });
  });
});
