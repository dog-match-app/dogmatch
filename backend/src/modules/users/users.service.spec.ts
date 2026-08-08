import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaService } from '../../prisma/prisma.service';
import { UsersService } from './users.service';

const REQUESTER_ID = 'aaaaaaaa-0000-4000-8000-000000000001';
const TARGET_ID = 'bbbbbbbb-0000-4000-8000-000000000002';
const DOG_1 = 'cccccccc-0000-4000-8000-000000000001';
const DOG_2 = 'cccccccc-0000-4000-8000-000000000002';
const DOG_3 = 'cccccccc-0000-4000-8000-000000000003';
const DOG_INACTIVE = 'cccccccc-0000-4000-8000-000000000004';

const makeDog = (id: string, name: string, createdAt: string) => ({
  id,
  ownerId: TARGET_ID,
  name,
  breed: 'Labrador Retriever',
  sex: 'FEMALE',
  birthDate: new Date('2020-11-05T00:00:00.000Z'),
  size: 'LARGE',
  intent: 'BREEDING',
  bio: 'Friendly dog',
  neutered: false,
  pedigree: true,
  active: true,
  socialWhatsapp: null,
  socialInstagram: '@mel.labrador',
  socialPinterest: null,
  socialTelegram: null,
  createdAt: new Date(createdAt),
  updatedAt: new Date(createdAt),
  photos: [
    {
      id: `photo-${id}`,
      dogId: id,
      key: `dogs/${id}.jpg`,
      url: `https://cdn.example.com/dogs/${id}.jpg`,
      position: 0,
      createdAt: new Date(createdAt),
    },
  ],
});

// Full row as Prisma would return it: sensitive fields present on purpose so
// the privacy test proves the service never maps them into the response.
const makeTargetUser = () => ({
  id: TARGET_ID,
  email: 'bruno@demo.com',
  passwordHash: 'argon2-secret-hash',
  name: 'Bruno Lima',
  phone: '+55 11 91234-0002',
  bio: 'Pai de dois cachorros.',
  avatarUrl: 'https://i.pravatar.cc/300?img=12',
  city: 'São Paulo - Moema',
  latitude: -23.6015,
  longitude: -46.6659,
  createdAt: new Date('2024-05-10T12:00:00.000Z'),
  updatedAt: new Date('2024-05-10T12:00:00.000Z'),
  dogs: [
    makeDog(DOG_3, 'Amora', '2025-06-20T00:00:00.000Z'),
    makeDog(DOG_2, 'Rex', '2025-02-15T00:00:00.000Z'),
    makeDog(DOG_1, 'Mel', '2024-11-05T00:00:00.000Z'),
  ],
});

describe('UsersService (getOwnerProfile)', () => {
  let service: UsersService;

  const prismaMock = {
    user: { findUnique: jest.fn(), update: jest.fn() },
    dog: { findMany: jest.fn() },
    match: { count: jest.fn() },
    $queryRaw: jest.fn(),
  };

  const mockHappyPath = (): void => {
    prismaMock.user.findUnique
      .mockResolvedValueOnce(makeTargetUser())
      .mockResolvedValueOnce({ latitude: -23.5629, longitude: -46.6825 });
    prismaMock.dog.findMany.mockResolvedValue([
      { id: DOG_1 },
      { id: DOG_2 },
      { id: DOG_3 },
      { id: DOG_INACTIVE },
    ]);
    prismaMock.match.count.mockResolvedValue(2);
    prismaMock.$queryRaw.mockResolvedValue([{ distance_m: 4649.3 }]);
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const moduleRef = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();

    service = moduleRef.get(UsersService);
  });

  it('throws NotFound for an unknown user id', async () => {
    prismaMock.user.findUnique.mockResolvedValue(null);

    await expect(
      service.getOwnerProfile(REQUESTER_ID, TARGET_ID),
    ).rejects.toThrow(NotFoundException);
    expect(prismaMock.match.count).not.toHaveBeenCalled();
    expect(prismaMock.$queryRaw).not.toHaveBeenCalled();
  });

  it('maps stats, dogs, memberSince and distanceKm on the happy path', async () => {
    mockHappyPath();

    const profile = await service.getOwnerProfile(REQUESTER_ID, TARGET_ID);

    expect(profile.id).toBe(TARGET_ID);
    expect(profile.name).toBe('Bruno Lima');
    expect(profile.bio).toBe('Pai de dois cachorros.');
    expect(profile.avatarUrl).toBe('https://i.pravatar.cc/300?img=12');
    expect(profile.city).toBe('São Paulo - Moema');
    expect(profile.memberSince).toBe('2024-05-10T12:00:00.000Z');
    expect(profile.distanceKm).toBe(4.6);
    expect(profile.stats).toEqual({ dogs: 3, matches: 2 });
    expect(profile.dogs.map((dog) => dog.id)).toEqual([DOG_3, DOG_2, DOG_1]);
    expect(profile.dogs[0].photos).toEqual([
      {
        id: `photo-${DOG_3}`,
        url: `https://cdn.example.com/dogs/${DOG_3}.jpg`,
        position: 0,
      },
    ]);
    expect(profile.dogs[0].social).toEqual({
      whatsapp: null,
      instagram: '@mel.labrador',
      pinterest: null,
      telegram: null,
    });
    // Matches are counted with OR over dogAId/dogBId across ALL of the
    // owner's dog ids (including inactive ones).
    expect(prismaMock.match.count).toHaveBeenCalledWith({
      where: {
        OR: [
          { dogAId: { in: [DOG_1, DOG_2, DOG_3, DOG_INACTIVE] } },
          { dogBId: { in: [DOG_1, DOG_2, DOG_3, DOG_INACTIVE] } },
        ],
      },
    });
    expect(prismaMock.$queryRaw).toHaveBeenCalledTimes(1);
  });

  it('returns distanceKm null when the requester has no location', async () => {
    prismaMock.user.findUnique
      .mockResolvedValueOnce(makeTargetUser())
      .mockResolvedValueOnce({ latitude: null, longitude: null });
    prismaMock.dog.findMany.mockResolvedValue([{ id: DOG_1 }]);
    prismaMock.match.count.mockResolvedValue(1);

    const profile = await service.getOwnerProfile(REQUESTER_ID, TARGET_ID);

    expect(profile.distanceKm).toBeNull();
    expect(prismaMock.$queryRaw).not.toHaveBeenCalled();
  });

  it('returns distanceKm null when viewing your own profile', async () => {
    prismaMock.user.findUnique.mockResolvedValueOnce(makeTargetUser());
    prismaMock.dog.findMany.mockResolvedValue([{ id: DOG_1 }]);
    prismaMock.match.count.mockResolvedValue(1);

    const profile = await service.getOwnerProfile(TARGET_ID, TARGET_ID);

    expect(profile.distanceKm).toBeNull();
    // Only the target lookup — no second findUnique for the requester.
    expect(prismaMock.user.findUnique).toHaveBeenCalledTimes(1);
    expect(prismaMock.$queryRaw).not.toHaveBeenCalled();
  });

  it('never leaks email, phone, coordinates or hashes in the response', async () => {
    mockHappyPath();

    const profile = await service.getOwnerProfile(REQUESTER_ID, TARGET_ID);
    const json = JSON.stringify(profile);

    for (const forbiddenKey of [
      'email',
      'phone',
      'latitude',
      'longitude',
      'passwordHash',
    ]) {
      expect(json).not.toContain(forbiddenKey);
    }
    for (const forbiddenValue of [
      'bruno@demo.com',
      '91234',
      'argon2-secret-hash',
      '-23.6015',
      '-46.6659',
    ]) {
      expect(json).not.toContain(forbiddenValue);
    }
  });
});
