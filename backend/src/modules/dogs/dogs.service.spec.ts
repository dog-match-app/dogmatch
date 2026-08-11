import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { DogIntent, DogSex, DogSize } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateDogDto } from './dto/create-dog.dto';
import { DogsService } from './dogs.service';

const USER_ID = 'user-1';
const DOG_ID = 'dog-1';

const baseDto: CreateDogDto = {
  name: 'Rex',
  breed: 'SRD',
  sex: DogSex.MALE,
  birthDate: '2022-01-15T00:00:00.000Z',
  size: DogSize.MEDIUM,
  intent: DogIntent.BREEDING,
};

describe('DogsService intent compatibility', () => {
  let service: DogsService;

  const prismaMock = {
    dog: { create: jest.fn(), update: jest.fn(), findUnique: jest.fn() },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const moduleRef = await Test.createTestingModule({
      providers: [
        DogsService,
        { provide: PrismaService, useValue: prismaMock },
        {
          provide: ConfigService,
          useValue: { getOrThrow: () => 'http://localhost:9000/media' },
        },
      ],
    }).compile();
    service = moduleRef.get(DogsService);
  });

  it('rejects creating a neutered dog with breeding-only intent', async () => {
    await expect(
      service.create(USER_ID, { ...baseDto, neutered: true }),
    ).rejects.toThrow(BadRequestException);
    expect(prismaMock.dog.create).not.toHaveBeenCalled();
  });

  it('allows a neutered dog with BOTH intent', async () => {
    prismaMock.dog.create.mockResolvedValue({
      id: DOG_ID,
      ownerId: USER_ID,
      name: 'Rex',
      breed: 'SRD',
      sex: DogSex.MALE,
      birthDate: new Date('2022-01-15T00:00:00.000Z'),
      size: DogSize.MEDIUM,
      intent: DogIntent.BOTH,
      bio: null,
      neutered: true,
      pedigree: false,
      active: true,
      socialWhatsapp: null,
      socialInstagram: null,
      socialPinterest: null,
      socialTelegram: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      photos: [],
    });

    const dog = await service.create(USER_ID, {
      ...baseDto,
      intent: DogIntent.BOTH,
      neutered: true,
    });
    expect(dog.intent).toBe(DogIntent.BOTH);
  });

  it('rejects an update whose merged state becomes neutered + breeding-only', async () => {
    prismaMock.dog.findUnique.mockResolvedValue({
      id: DOG_ID,
      ownerId: USER_ID,
      intent: DogIntent.BREEDING,
      neutered: false,
    });

    await expect(
      service.update(USER_ID, DOG_ID, { neutered: true }),
    ).rejects.toThrow(BadRequestException);
    expect(prismaMock.dog.update).not.toHaveBeenCalled();
  });
});
