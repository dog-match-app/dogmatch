import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Prisma, SwipeAction } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { DiscoveryService, PASS_COOLDOWN_DAYS } from './discovery.service';

const USER_ID = 'user-ana';
const OTHER_USER_ID = 'user-bruno';
const MY_DOG_ID = 'aaaaaaaa-0000-4000-8000-000000000001';
const TARGET_1 = 'bbbbbbbb-0000-4000-8000-000000000002';
const TARGET_2 = 'cccccccc-0000-4000-8000-000000000003';

const makeUser = (
  id: string,
  location: { latitude: number | null; longitude: number | null },
) => ({
  id,
  email: `${id}@demo.com`,
  passwordHash: 'hash',
  name: 'Ana',
  phone: null,
  bio: null,
  avatarUrl: null,
  city: 'São Paulo',
  latitude: location.latitude,
  longitude: location.longitude,
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
  owner: makeUser(ownerId, { latitude: -23.6, longitude: -46.66 }),
});

describe('DiscoveryService (discover)', () => {
  let service: DiscoveryService;

  const prismaMock = {
    dog: { findUnique: jest.fn(), findMany: jest.fn() },
    $queryRaw: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    prismaMock.dog.findUnique.mockResolvedValue({
      ...makeDog(MY_DOG_ID, USER_ID, 'Thor'),
      owner: makeUser(USER_ID, { latitude: -23.5629, longitude: -46.6825 }),
    });

    const moduleRef = await Test.createTestingModule({
      providers: [
        DiscoveryService,
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();

    service = moduleRef.get(DiscoveryService);
  });

  it('keeps a dog at the exact same location in the deck (distance_m = 0 maps to distanceKm 0)', async () => {
    prismaMock.$queryRaw.mockResolvedValue([{ id: TARGET_1, distance_m: 0 }]);
    prismaMock.dog.findMany.mockResolvedValue([
      makeDog(TARGET_1, OTHER_USER_ID, 'Rex'),
    ]);

    const cards = await service.discover(USER_ID, { dogId: MY_DOG_ID });

    expect(cards).toHaveLength(1);
    expect(cards[0].dog.id).toBe(TARGET_1);
    expect(cards[0].distanceKm).toBe(0);
    expect(cards[0].owner.id).toBe(OTHER_USER_ID);
  });

  it('excludes swiped targets via LIKE always but PASS only within the cooldown window', async () => {
    prismaMock.$queryRaw.mockResolvedValue([]);

    await expect(
      service.discover(USER_ID, { dogId: MY_DOG_ID }),
    ).resolves.toEqual([]);

    const sqlArg = (
      prismaMock.$queryRaw.mock.calls as unknown as [[Prisma.Sql]]
    )[0][0];
    expect(sqlArg.sql).toContain(`s.action::text = 'LIKE'`);
    expect(sqlArg.sql).toContain(`s.action::text = 'PASS'`);
    expect(sqlArg.sql).toContain('make_interval(days => ?::int)');
    expect(sqlArg.values).toContain(PASS_COOLDOWN_DAYS);
  });

  it('rejects a dog the user does not own with 403', async () => {
    prismaMock.dog.findUnique.mockResolvedValue(
      makeDog(TARGET_1, OTHER_USER_ID, 'Rex'),
    );

    await expect(
      service.discover(USER_ID, { dogId: TARGET_1 }),
    ).rejects.toThrow(ForbiddenException);
    expect(prismaMock.$queryRaw).not.toHaveBeenCalled();
  });

  it('rejects an unknown dog with 404', async () => {
    prismaMock.dog.findUnique.mockResolvedValue(null);

    await expect(
      service.discover(USER_ID, { dogId: MY_DOG_ID }),
    ).rejects.toThrow(NotFoundException);
  });

  it('rejects a browsing dog whose owner has no location (LOCATION_REQUIRED)', async () => {
    prismaMock.dog.findUnique.mockResolvedValue({
      ...makeDog(MY_DOG_ID, USER_ID, 'Thor'),
      owner: makeUser(USER_ID, { latitude: null, longitude: null }),
    });

    await expect(
      service.discover(USER_ID, { dogId: MY_DOG_ID }),
    ).rejects.toMatchObject({ message: 'LOCATION_REQUIRED' });
    expect(prismaMock.$queryRaw).not.toHaveBeenCalled();
  });
});

describe('DiscoveryService (search)', () => {
  let service: DiscoveryService;

  const prismaMock = {
    user: { findUnique: jest.fn() },
    dog: { findUnique: jest.fn(), findMany: jest.fn() },
    swipe: { findMany: jest.fn() },
    match: { findMany: jest.fn() },
    $queryRaw: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    prismaMock.user.findUnique.mockResolvedValue(
      makeUser(USER_ID, { latitude: -23.5629, longitude: -46.6825 }),
    );
    prismaMock.swipe.findMany.mockResolvedValue([]);
    prismaMock.match.findMany.mockResolvedValue([]);

    const moduleRef = await Test.createTestingModule({
      providers: [
        DiscoveryService,
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();

    service = moduleRef.get(DiscoveryService);
  });

  it('rejects excludeSwiped without dogId with 400', async () => {
    await expect(
      service.search(USER_ID, { excludeSwiped: true }),
    ).rejects.toThrow(BadRequestException);
    expect(prismaMock.user.findUnique).not.toHaveBeenCalled();
    expect(prismaMock.$queryRaw).not.toHaveBeenCalled();
  });

  it('rejects ageMinYears greater than ageMaxYears with 400', async () => {
    await expect(
      service.search(USER_ID, { ageMinYears: 5, ageMaxYears: 2 }),
    ).rejects.toThrow(BadRequestException);
    expect(prismaMock.$queryRaw).not.toHaveBeenCalled();
  });

  it('rejects radiusKm when the user has no location (LOCATION_REQUIRED)', async () => {
    prismaMock.user.findUnique.mockResolvedValue(
      makeUser(USER_ID, { latitude: null, longitude: null }),
    );

    await expect(service.search(USER_ID, { radiusKm: 10 })).rejects.toThrow(
      BadRequestException,
    );
    await expect(
      service.search(USER_ID, { radiusKm: 10 }),
    ).rejects.toMatchObject({ message: 'LOCATION_REQUIRED' });
    expect(prismaMock.$queryRaw).not.toHaveBeenCalled();
  });

  it('rejects orderBy=distance when the user has no location (LOCATION_REQUIRED)', async () => {
    prismaMock.user.findUnique.mockResolvedValue(
      makeUser(USER_ID, { latitude: null, longitude: null }),
    );

    await expect(
      service.search(USER_ID, { orderBy: 'distance' }),
    ).rejects.toMatchObject({ message: 'LOCATION_REQUIRED' });
    expect(prismaMock.$queryRaw).not.toHaveBeenCalled();
  });

  it('rejects dogId that belongs to another user with 403', async () => {
    prismaMock.dog.findUnique.mockResolvedValue(
      makeDog(TARGET_1, OTHER_USER_ID, 'Rex'),
    );

    await expect(service.search(USER_ID, { dogId: TARGET_1 })).rejects.toThrow(
      ForbiddenException,
    );
    expect(prismaMock.$queryRaw).not.toHaveBeenCalled();
  });

  it('rejects unknown dogId with 404', async () => {
    prismaMock.dog.findUnique.mockResolvedValue(null);

    await expect(service.search(USER_ID, { dogId: MY_DOG_ID })).rejects.toThrow(
      NotFoundException,
    );
  });

  it('maps rows to SearchResultDto preserving order, with correct pageCount', async () => {
    prismaMock.$queryRaw
      .mockResolvedValueOnce([{ count: 3 }])
      .mockResolvedValueOnce([
        { id: TARGET_1, distance_m: 1234 },
        { id: TARGET_2, distance_m: null },
      ]);
    // Scrambled on purpose: the service must restore the row order.
    prismaMock.dog.findMany.mockResolvedValue([
      makeDog(TARGET_2, OTHER_USER_ID, 'Nina'),
      makeDog(TARGET_1, OTHER_USER_ID, 'Rex'),
    ]);

    const result = await service.search(USER_ID, { page: 1, limit: 2 });

    expect(result.total).toBe(3);
    expect(result.page).toBe(1);
    expect(result.pageCount).toBe(2);
    expect(result.items.map((item) => item.dog.id)).toEqual([
      TARGET_1,
      TARGET_2,
    ]);
    expect(result.items[0].distanceKm).toBe(1.2);
    expect(result.items[1].distanceKm).toBeNull();
    expect(result.items[0].owner.id).toBe(OTHER_USER_ID);
    expect(result.items[0].isMine).toBe(false);
    expect(result.items[0].myAction).toBeUndefined();
    expect(result.items[0].matched).toBeUndefined();
    expect(prismaMock.$queryRaw).toHaveBeenCalledTimes(2);
    expect(prismaMock.swipe.findMany).not.toHaveBeenCalled();
    expect(prismaMock.match.findMany).not.toHaveBeenCalled();
  });

  it('includes the caller own dogs flagged with isMine and no swipe state', async () => {
    prismaMock.dog.findUnique.mockResolvedValue(
      makeDog(MY_DOG_ID, USER_ID, 'Thor'),
    );
    prismaMock.$queryRaw
      .mockResolvedValueOnce([{ count: 2 }])
      .mockResolvedValueOnce([
        { id: MY_DOG_ID, distance_m: 0 },
        { id: TARGET_1, distance_m: 900 },
      ]);
    prismaMock.dog.findMany.mockResolvedValue([
      makeDog(MY_DOG_ID, USER_ID, 'Thor'),
      makeDog(TARGET_1, OTHER_USER_ID, 'Rex'),
    ]);
    prismaMock.swipe.findMany.mockResolvedValue([]);
    prismaMock.match.findMany.mockResolvedValue([]);

    const result = await service.search(USER_ID, { dogId: MY_DOG_ID });

    expect(result.items[0].isMine).toBe(true);
    // Zero distance must survive the mapping (0 is not "missing").
    expect(result.items[0].distanceKm).toBe(0);
    expect(result.items[0].myAction).toBeUndefined();
    expect(result.items[0].matched).toBeUndefined();
    expect(result.items[1].isMine).toBe(false);
    expect(result.items[1].matched).toBe(false);
  });

  it('fills myAction and matched from the dogId perspective', async () => {
    prismaMock.dog.findUnique.mockResolvedValue(
      makeDog(MY_DOG_ID, USER_ID, 'Thor'),
    );
    prismaMock.$queryRaw
      .mockResolvedValueOnce([{ count: 2 }])
      .mockResolvedValueOnce([
        { id: TARGET_1, distance_m: 500 },
        { id: TARGET_2, distance_m: 2000 },
      ]);
    prismaMock.dog.findMany.mockResolvedValue([
      makeDog(TARGET_1, OTHER_USER_ID, 'Mel'),
      makeDog(TARGET_2, OTHER_USER_ID, 'Nina'),
    ]);
    prismaMock.swipe.findMany.mockResolvedValue([
      {
        id: 'swipe-1',
        swiperDogId: MY_DOG_ID,
        targetDogId: TARGET_1,
        action: SwipeAction.LIKE,
        createdAt: new Date(),
      },
    ]);
    prismaMock.match.findMany.mockResolvedValue([
      {
        id: 'match-1',
        dogAId: MY_DOG_ID,
        dogBId: TARGET_1,
        createdAt: new Date(),
      },
    ]);

    const result = await service.search(USER_ID, { dogId: MY_DOG_ID });

    expect(result.total).toBe(2);
    expect(result.pageCount).toBe(1);
    expect(result.items[0].myAction).toBe(SwipeAction.LIKE);
    expect(result.items[0].matched).toBe(true);
    expect(result.items[1].myAction).toBeNull();
    expect(result.items[1].matched).toBe(false);
    expect(prismaMock.swipe.findMany).toHaveBeenCalledWith({
      where: {
        swiperDogId: MY_DOG_ID,
        targetDogId: { in: [TARGET_1, TARGET_2] },
      },
    });
  });

  it('returns an empty page without running the page query when total is 0', async () => {
    prismaMock.$queryRaw.mockResolvedValueOnce([{ count: 0 }]);

    const result = await service.search(USER_ID, {});

    expect(result).toEqual({ items: [], total: 0, page: 1, pageCount: 0 });
    expect(prismaMock.$queryRaw).toHaveBeenCalledTimes(1);
    expect(prismaMock.dog.findMany).not.toHaveBeenCalled();
  });
});
