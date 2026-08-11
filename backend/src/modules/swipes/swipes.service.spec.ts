import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Test } from '@nestjs/testing';
import { Prisma, SwipeAction } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { LIKES_RECEIVED_TAKE, SwipesService } from './swipes.service';

const USER_A = 'user-a';
const USER_B = 'user-b';
const SWIPER_DOG_ID = 'bbbbbbbb-0000-4000-8000-000000000002';
const TARGET_DOG_ID = 'aaaaaaaa-0000-4000-8000-000000000001';

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
});

describe('SwipesService', () => {
  let service: SwipesService;

  const txMock = {
    dog: { findUnique: jest.fn() },
    swipe: { upsert: jest.fn(), findUnique: jest.fn() },
    match: { findUnique: jest.fn(), create: jest.fn() },
  };
  const prismaMock = {
    $transaction: jest.fn((fn: (tx: typeof txMock) => Promise<unknown>) =>
      fn(txMock),
    ),
    message: { count: jest.fn() },
  };
  const eventEmitterMock = { emit: jest.fn() };

  const swiperDog = makeDog(SWIPER_DOG_ID, USER_A, 'Thor');
  const targetDog = makeDog(TARGET_DOG_ID, USER_B, 'Mel');

  beforeEach(async () => {
    jest.clearAllMocks();
    txMock.dog.findUnique.mockImplementation(
      (args: { where: { id: string } }) =>
        Promise.resolve(
          args.where.id === SWIPER_DOG_ID
            ? swiperDog
            : args.where.id === TARGET_DOG_ID
              ? targetDog
              : null,
        ),
    );
    txMock.swipe.upsert.mockResolvedValue({});
    txMock.match.findUnique.mockResolvedValue(null);
    prismaMock.message.count.mockResolvedValue(0);

    const moduleRef = await Test.createTestingModule({
      providers: [
        SwipesService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: EventEmitter2, useValue: eventEmitterMock },
      ],
    }).compile();

    service = moduleRef.get(SwipesService);
  });

  it('creates a match with dogAId < dogBId on mutual like', async () => {
    txMock.swipe.findUnique.mockResolvedValue({
      id: 'swipe-reverse',
      swiperDogId: TARGET_DOG_ID,
      targetDogId: SWIPER_DOG_ID,
      action: SwipeAction.LIKE,
      createdAt: new Date(),
    });
    txMock.match.create.mockImplementation(
      (args: { data: { dogAId: string; dogBId: string } }) =>
        Promise.resolve({
          id: 'match-1',
          dogAId: args.data.dogAId,
          dogBId: args.data.dogBId,
          createdAt: new Date(),
          dogA: { ...targetDog, photos: [], owner: makeOwner(USER_B, 'Bruno') },
          dogB: { ...swiperDog, photos: [], owner: makeOwner(USER_A, 'Ana') },
          messages: [],
        }),
    );

    const result = await service.swipe(USER_A, {
      swiperDogId: SWIPER_DOG_ID,
      targetDogId: TARGET_DOG_ID,
      action: SwipeAction.LIKE,
    });

    expect(result.matched).toBe(true);
    const createArgs = (
      txMock.match.create.mock.calls as unknown as [
        [{ data: { dogAId: string; dogBId: string } }],
      ]
    )[0][0];
    expect(createArgs.data.dogAId).toBe(TARGET_DOG_ID);
    expect(createArgs.data.dogBId).toBe(SWIPER_DOG_ID);
    expect(createArgs.data.dogAId < createArgs.data.dogBId).toBe(true);
    expect(result.match?.myDog.id).toBe(SWIPER_DOG_ID);
    expect(result.match?.otherDog.id).toBe(TARGET_DOG_ID);
    // Fresh match: no messages can exist yet, so no unread count query runs.
    expect(result.match?.unreadCount).toBe(0);
    expect(prismaMock.message.count).not.toHaveBeenCalled();
    expect(eventEmitterMock.emit).toHaveBeenCalledTimes(1);
    const emitArgs = (
      eventEmitterMock.emit.mock.calls as unknown as [[string, unknown]]
    )[0];
    expect(emitArgs[0]).toBe('match.created');
  });

  it('returns matched=false when there is no reverse like', async () => {
    txMock.swipe.findUnique.mockResolvedValue(null);

    const result = await service.swipe(USER_A, {
      swiperDogId: SWIPER_DOG_ID,
      targetDogId: TARGET_DOG_ID,
      action: SwipeAction.LIKE,
    });

    expect(result).toEqual({ matched: false });
    expect(txMock.match.create).not.toHaveBeenCalled();
    expect(eventEmitterMock.emit).not.toHaveBeenCalled();
  });

  it('re-swipe PASS -> LIKE updates action + createdAt and creates the match on reverse like', async () => {
    txMock.swipe.findUnique.mockResolvedValue({
      id: 'swipe-reverse',
      swiperDogId: TARGET_DOG_ID,
      targetDogId: SWIPER_DOG_ID,
      action: SwipeAction.LIKE,
      createdAt: new Date(),
    });
    txMock.match.create.mockResolvedValue({
      id: 'match-1',
      dogAId: TARGET_DOG_ID,
      dogBId: SWIPER_DOG_ID,
      createdAt: new Date(),
      dogA: { ...targetDog, photos: [], owner: makeOwner(USER_B, 'Bruno') },
      dogB: { ...swiperDog, photos: [], owner: makeOwner(USER_A, 'Ana') },
      messages: [],
    });

    const result = await service.swipe(USER_A, {
      swiperDogId: SWIPER_DOG_ID,
      targetDogId: TARGET_DOG_ID,
      action: SwipeAction.LIKE,
    });

    const upsertArgs = (
      txMock.swipe.upsert.mock.calls as unknown as [
        [{ update: { action: SwipeAction; createdAt: Date } }],
      ]
    )[0][0];
    expect(upsertArgs.update.action).toBe(SwipeAction.LIKE);
    expect(upsertArgs.update.createdAt).toBeInstanceOf(Date);
    expect(result.matched).toBe(true);
    expect(result.match?.id).toBe('match-1');
    expect(eventEmitterMock.emit).toHaveBeenCalledTimes(1);
  });

  it('re-swipe PASS -> LIKE returns matched=false when the reverse swipe is a PASS', async () => {
    txMock.swipe.findUnique.mockResolvedValue({
      id: 'swipe-reverse',
      swiperDogId: TARGET_DOG_ID,
      targetDogId: SWIPER_DOG_ID,
      action: SwipeAction.PASS,
      createdAt: new Date(),
    });

    const result = await service.swipe(USER_A, {
      swiperDogId: SWIPER_DOG_ID,
      targetDogId: TARGET_DOG_ID,
      action: SwipeAction.LIKE,
    });

    expect(result).toEqual({ matched: false });
    expect(txMock.match.create).not.toHaveBeenCalled();
    expect(eventEmitterMock.emit).not.toHaveBeenCalled();
  });

  it('re-LIKE with an existing match returns it without recreating (no unique violation)', async () => {
    txMock.swipe.findUnique.mockResolvedValue({
      id: 'swipe-reverse',
      swiperDogId: TARGET_DOG_ID,
      targetDogId: SWIPER_DOG_ID,
      action: SwipeAction.LIKE,
      createdAt: new Date(),
    });
    txMock.match.findUnique.mockResolvedValue({
      id: 'match-existing',
      dogAId: TARGET_DOG_ID,
      dogBId: SWIPER_DOG_ID,
      createdAt: new Date(),
      dogA: { ...targetDog, photos: [], owner: makeOwner(USER_B, 'Bruno') },
      dogB: { ...swiperDog, photos: [], owner: makeOwner(USER_A, 'Ana') },
      messages: [],
    });
    prismaMock.message.count.mockResolvedValue(3);

    const result = await service.swipe(USER_A, {
      swiperDogId: SWIPER_DOG_ID,
      targetDogId: TARGET_DOG_ID,
      action: SwipeAction.LIKE,
    });

    expect(result.matched).toBe(true);
    expect(result.match?.id).toBe('match-existing');
    // Pre-existing match may carry unread history from the other owner.
    expect(result.match?.unreadCount).toBe(3);
    const countArgs = (
      prismaMock.message.count.mock.calls as unknown as [
        [{ where: Record<string, unknown> }],
      ]
    )[0][0];
    expect(countArgs.where).toEqual({
      matchId: 'match-existing',
      senderId: { not: USER_A },
      readAt: null,
    });
    expect(txMock.match.create).not.toHaveBeenCalled();
    // The match already exists, so no match.created event is re-emitted.
    expect(eventEmitterMock.emit).not.toHaveBeenCalled();
  });

  it('re-PASS only renews createdAt (restarting the feed cooldown window)', async () => {
    const result = await service.swipe(USER_A, {
      swiperDogId: SWIPER_DOG_ID,
      targetDogId: TARGET_DOG_ID,
      action: SwipeAction.PASS,
    });

    const upsertArgs = (
      txMock.swipe.upsert.mock.calls as unknown as [
        [{ update: { action: SwipeAction; createdAt: Date } }],
      ]
    )[0][0];
    expect(upsertArgs.update.action).toBe(SwipeAction.PASS);
    expect(upsertArgs.update.createdAt).toBeInstanceOf(Date);
    expect(result).toEqual({ matched: false });
    expect(txMock.swipe.findUnique).not.toHaveBeenCalled();
    expect(txMock.match.create).not.toHaveBeenCalled();
    expect(eventEmitterMock.emit).not.toHaveBeenCalled();
  });
});

describe('SwipesService (likesReceived)', () => {
  let service: SwipesService;

  const prismaMock = {
    dog: { findUnique: jest.fn() },
    swipe: { count: jest.fn(), findMany: jest.fn() },
    $queryRaw: jest.fn(),
  };

  const MY_DOG_ID = 'dddddddd-0000-4000-8000-000000000004';
  const LIKER_DOG_ID = 'eeeeeeee-0000-4000-8000-000000000005';
  const LIKED_AT = new Date('2026-08-10T12:00:00.000Z');

  const likerDog = {
    ...makeDog(LIKER_DOG_ID, USER_B, 'Rex'),
    photos: [],
    owner: makeOwner(USER_B, 'Bruno'),
  };
  const makeLike = () => ({
    id: 'swipe-like',
    swiperDogId: LIKER_DOG_ID,
    targetDogId: MY_DOG_ID,
    action: SwipeAction.LIKE,
    createdAt: LIKED_AT,
    swiperDog: likerDog,
  });

  type LikesWhere = {
    targetDogId: string;
    action: SwipeAction;
    swiperDog: {
      active: boolean;
      ownerId: { not: string };
      swipesReceived: { none: { swiperDogId: string; action: SwipeAction } };
      matchesAsA: { none: { dogBId: string } };
      matchesAsB: { none: { dogAId: string } };
    };
  };
  type LikesFindManyArgs = {
    where: LikesWhere;
    orderBy: unknown;
    take: number;
  };
  const likesFindManyArgs = (): LikesFindManyArgs =>
    (
      prismaMock.swipe.findMany.mock.calls as unknown as [[LikesFindManyArgs]]
    )[0][0];

  beforeEach(async () => {
    jest.clearAllMocks();
    prismaMock.dog.findUnique.mockResolvedValue({
      ...makeDog(MY_DOG_ID, USER_A, 'Luna'),
      owner: {
        ...makeOwner(USER_A, 'Ana'),
        latitude: -23.5629,
        longitude: -46.6825,
      },
    });
    prismaMock.swipe.count.mockResolvedValue(0);
    prismaMock.swipe.findMany.mockResolvedValue([]);
    prismaMock.$queryRaw.mockResolvedValue([]);

    const moduleRef = await Test.createTestingModule({
      providers: [
        SwipesService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: EventEmitter2, useValue: { emit: jest.fn() } },
      ],
    }).compile();

    service = moduleRef.get(SwipesService);
  });

  it('lists a pending like with likedAt, owner distance and myAction null', async () => {
    prismaMock.swipe.count.mockResolvedValue(1);
    prismaMock.swipe.findMany
      .mockResolvedValueOnce([makeLike()])
      .mockResolvedValueOnce([]);
    prismaMock.$queryRaw.mockResolvedValue([{ id: USER_B, distance_m: 4321 }]);

    const result = await service.likesReceived(USER_A, MY_DOG_ID);

    expect(result.total).toBe(1);
    expect(result.items).toHaveLength(1);
    expect(result.items[0].dog.id).toBe(LIKER_DOG_ID);
    expect(result.items[0].likedAt).toBe(LIKED_AT.toISOString());
    expect(result.items[0].myAction).toBeNull();
    expect(result.items[0].distanceKm).toBe(4.3);
    expect(result.items[0].owner.id).toBe(USER_B);
    const args = likesFindManyArgs();
    expect(args.orderBy).toEqual({ createdAt: 'desc' });
    expect(args.take).toBe(LIKES_RECEIVED_TAKE);
    // total must be counted with the exact same filters as the page query.
    const countArgs = (
      prismaMock.swipe.count.mock.calls as unknown as [[{ where: unknown }]]
    )[0][0];
    expect(countArgs.where).toBe(args.where);
    // Distance query only targets the owners of the returned likes.
    const sqlArg = (
      prismaMock.$queryRaw.mock.calls as unknown as [[Prisma.Sql]]
    )[0][0];
    expect(sqlArg.sql).toContain('ST_Distance');
    expect(sqlArg.values).toContain(USER_B);
  });

  it('excludes likes that already turned into a match (both pair orderings)', async () => {
    const result = await service.likesReceived(USER_A, MY_DOG_ID);

    expect(result).toEqual({ items: [], total: 0 });
    const { swiperDog } = likesFindManyArgs().where;
    expect(swiperDog.matchesAsA).toEqual({ none: { dogBId: MY_DOG_ID } });
    expect(swiperDog.matchesAsB).toEqual({ none: { dogAId: MY_DOG_ID } });
    expect(prismaMock.$queryRaw).not.toHaveBeenCalled();
  });

  it('excludes likers I already liked back, but not the ones I passed', async () => {
    await service.likesReceived(USER_A, MY_DOG_ID);

    const { where } = likesFindManyArgs();
    expect(where.action).toBe(SwipeAction.LIKE);
    // Only a reciprocal LIKE hides the liker — my PASS keeps it listed.
    expect(where.swiperDog.swipesReceived).toEqual({
      none: { swiperDogId: MY_DOG_ID, action: SwipeAction.LIKE },
    });
    expect(where.swiperDog.active).toBe(true);
    expect(where.swiperDog.ownerId).toEqual({ not: USER_A });
  });

  it('marks likers I passed with myAction PASS and null distance without my location', async () => {
    prismaMock.dog.findUnique.mockResolvedValue({
      ...makeDog(MY_DOG_ID, USER_A, 'Luna'),
      owner: makeOwner(USER_A, 'Ana'),
    });
    prismaMock.swipe.count.mockResolvedValue(1);
    prismaMock.swipe.findMany
      .mockResolvedValueOnce([makeLike()])
      .mockResolvedValueOnce([
        {
          id: 'swipe-my-pass',
          swiperDogId: MY_DOG_ID,
          targetDogId: LIKER_DOG_ID,
          action: SwipeAction.PASS,
          createdAt: new Date(),
        },
      ]);

    const result = await service.likesReceived(USER_A, MY_DOG_ID);

    expect(result.items[0].myAction).toBe('PASS');
    expect(result.items[0].distanceKm).toBeNull();
    expect(prismaMock.$queryRaw).not.toHaveBeenCalled();
    const passArgs = (
      prismaMock.swipe.findMany.mock.calls as unknown as [
        unknown,
        [{ where: unknown }],
      ]
    )[1][0];
    expect(passArgs.where).toEqual({
      swiperDogId: MY_DOG_ID,
      targetDogId: { in: [LIKER_DOG_ID] },
      action: SwipeAction.PASS,
    });
  });

  it('rejects a dog the user does not own with 403', async () => {
    prismaMock.dog.findUnique.mockResolvedValue({
      ...makeDog(LIKER_DOG_ID, USER_B, 'Rex'),
      owner: makeOwner(USER_B, 'Bruno'),
    });

    await expect(service.likesReceived(USER_A, LIKER_DOG_ID)).rejects.toThrow(
      ForbiddenException,
    );
    expect(prismaMock.swipe.count).not.toHaveBeenCalled();
    expect(prismaMock.swipe.findMany).not.toHaveBeenCalled();
  });

  it('rejects an unknown dog with 404', async () => {
    prismaMock.dog.findUnique.mockResolvedValue(null);

    await expect(service.likesReceived(USER_A, MY_DOG_ID)).rejects.toThrow(
      NotFoundException,
    );
    expect(prismaMock.swipe.count).not.toHaveBeenCalled();
  });
});

describe('SwipesService (likesReceived aggregate)', () => {
  let service: SwipesService;

  const prismaMock = {
    dog: { findUnique: jest.fn(), findMany: jest.fn() },
    swipe: { count: jest.fn(), findMany: jest.fn() },
    $queryRaw: jest.fn(),
  };

  const DOG_1 = 'dddddddd-0000-4000-8000-000000000004';
  const DOG_2 = 'ffffffff-0000-4000-8000-000000000006';
  const LIKER_DOG_ID = 'eeeeeeee-0000-4000-8000-000000000005';

  beforeEach(async () => {
    jest.clearAllMocks();
    const owner = {
      ...makeOwner(USER_A, 'Ana'),
      latitude: -23.5629,
      longitude: -46.6825,
    };
    prismaMock.dog.findMany.mockResolvedValue([
      { ...makeDog(DOG_1, USER_A, 'Luna'), owner },
      { ...makeDog(DOG_2, USER_A, 'Thor'), owner },
    ]);
    prismaMock.$queryRaw.mockResolvedValue([]);

    const moduleRef = await Test.createTestingModule({
      providers: [
        SwipesService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: EventEmitter2, useValue: { emit: jest.fn() } },
      ],
    }).compile();

    service = moduleRef.get(SwipesService);
  });

  it('without dogId aggregates pending likes across all active dogs', async () => {
    prismaMock.swipe.count.mockResolvedValueOnce(1).mockResolvedValueOnce(0);
    prismaMock.swipe.findMany
      .mockResolvedValueOnce([
        {
          id: 'swipe-like',
          swiperDogId: LIKER_DOG_ID,
          targetDogId: DOG_1,
          action: SwipeAction.LIKE,
          createdAt: new Date('2026-08-10T12:00:00.000Z'),
          swiperDog: {
            ...makeDog(LIKER_DOG_ID, USER_B, 'Rex'),
            photos: [],
            owner: makeOwner(USER_B, 'Bruno'),
          },
        },
      ])
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([]);

    const result = await service.likesReceived(USER_A);

    expect(prismaMock.dog.findUnique).not.toHaveBeenCalled();
    expect(prismaMock.dog.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { ownerId: USER_A, active: true },
      }),
    );
    expect(result.total).toBe(1);
    expect(result.items).toHaveLength(1);
    expect(result.items[0].dog.id).toBe(LIKER_DOG_ID);
  });

  it('without dogId and no dogs returns an empty page', async () => {
    prismaMock.dog.findMany.mockResolvedValue([]);

    const result = await service.likesReceived(USER_A);

    expect(result).toEqual({ items: [], total: 0 });
    expect(prismaMock.swipe.count).not.toHaveBeenCalled();
  });
});
