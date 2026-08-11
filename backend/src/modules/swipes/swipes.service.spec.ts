import { EventEmitter2 } from '@nestjs/event-emitter';
import { Test } from '@nestjs/testing';
import { SwipeAction } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { SwipesService } from './swipes.service';

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

    const result = await service.swipe(USER_A, {
      swiperDogId: SWIPER_DOG_ID,
      targetDogId: TARGET_DOG_ID,
      action: SwipeAction.LIKE,
    });

    expect(result.matched).toBe(true);
    expect(result.match?.id).toBe('match-existing');
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
