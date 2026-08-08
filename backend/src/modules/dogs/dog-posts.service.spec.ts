import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { DogPostType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { DogPostsService } from './dog-posts.service';

const OWNER_ID = 'user-ana';
const OTHER_USER_ID = 'user-bruno';
const DOG_ID = 'aaaaaaaa-0000-4000-8000-000000000001';
const POST_ID = 'dddddddd-0000-4000-8000-000000000001';
const PUBLIC_URL = 'https://cdn.example.com/dogmatch-media';

const makeDog = (ownerId: string) => ({
  id: DOG_ID,
  ownerId,
  name: 'Thor',
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

describe('DogPostsService', () => {
  let service: DogPostsService;

  const txMock = {
    dogPost: { create: jest.fn(), update: jest.fn() },
    dogPostImage: { deleteMany: jest.fn() },
  };
  const prismaMock = {
    dog: { findUnique: jest.fn() },
    dogPost: {
      count: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      delete: jest.fn(),
    },
    $transaction: jest.fn((fn: (tx: typeof txMock) => Promise<unknown>) =>
      fn(txMock),
    ),
  };
  const configMock = { getOrThrow: jest.fn().mockReturnValue(PUBLIC_URL) };

  beforeEach(async () => {
    jest.clearAllMocks();
    configMock.getOrThrow.mockReturnValue(PUBLIC_URL);
    prismaMock.dog.findUnique.mockResolvedValue(makeDog(OWNER_ID));
    prismaMock.dogPost.count.mockResolvedValue(0);

    const moduleRef = await Test.createTestingModule({
      providers: [
        DogPostsService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: ConfigService, useValue: configMock },
      ],
    }).compile();

    service = moduleRef.get(DogPostsService);
  });

  it('rejects the 11th post with 400 POST_LIMIT_REACHED', async () => {
    prismaMock.dogPost.count.mockResolvedValue(10);

    await expect(
      service.create(OWNER_ID, DOG_ID, {
        type: DogPostType.TEXT,
        text: 'Mais um post',
      }),
    ).rejects.toThrow(BadRequestException);
    await expect(
      service.create(OWNER_ID, DOG_ID, {
        type: DogPostType.TEXT,
        text: 'Mais um post',
      }),
    ).rejects.toMatchObject({ message: 'POST_LIMIT_REACHED' });
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it('rejects a TEXT post carrying images with 400', async () => {
    await expect(
      service.create(OWNER_ID, DOG_ID, {
        type: DogPostType.TEXT,
        text: 'Texto com imagem indevida',
        images: [{ key: 'dogs/a.jpg' }],
      }),
    ).rejects.toThrow(BadRequestException);
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it('rejects a CAROUSEL post with a single image with 400', async () => {
    await expect(
      service.create(OWNER_ID, DOG_ID, {
        type: DogPostType.CAROUSEL,
        images: [{ key: 'dogs/a.jpg' }],
      }),
    ).rejects.toThrow(BadRequestException);
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it('creates a CAROUSEL post mapping captions and building urls server-side', async () => {
    prismaMock.dogPost.count.mockResolvedValue(3);
    const createdAt = new Date('2026-08-08T12:00:00.000Z');
    txMock.dogPost.create.mockResolvedValue({
      id: POST_ID,
      dogId: DOG_ID,
      type: DogPostType.CAROUSEL,
      text: 'Melhores momentos',
      createdAt,
      updatedAt: createdAt,
      images: [
        {
          id: 'image-1',
          postId: POST_ID,
          key: 'dogs/a.jpg',
          url: `${PUBLIC_URL}/dogs/a.jpg`,
          position: 0,
          captions: [
            {
              id: 'caption-1',
              imageId: 'image-1',
              text: 'Cicatriz da aventura de 2024',
              x: 0.7,
              y: 0.3,
            },
            {
              id: 'caption-2',
              imageId: 'image-1',
              text: 'Coleira nova',
              x: 0.4,
              y: 0.8,
            },
          ],
        },
        {
          id: 'image-2',
          postId: POST_ID,
          key: 'dogs/b.jpg',
          url: `${PUBLIC_URL}/dogs/b.jpg`,
          position: 1,
          captions: [],
        },
      ],
    });

    const result = await service.create(OWNER_ID, DOG_ID, {
      type: DogPostType.CAROUSEL,
      text: 'Melhores momentos',
      images: [
        {
          key: 'dogs/a.jpg',
          captions: [
            { text: 'Cicatriz da aventura de 2024', x: 0.7, y: 0.3 },
            { text: 'Coleira nova', x: 0.4, y: 0.8 },
          ],
        },
        { key: 'dogs/b.jpg' },
      ],
    });

    expect(result.id).toBe(POST_ID);
    expect(result.type).toBe(DogPostType.CAROUSEL);
    expect(result.images).toHaveLength(2);
    expect(result.images[0].url).toBe(`${PUBLIC_URL}/dogs/a.jpg`);
    expect(result.images[0].captions).toEqual([
      {
        id: 'caption-1',
        text: 'Cicatriz da aventura de 2024',
        x: 0.7,
        y: 0.3,
      },
      { id: 'caption-2', text: 'Coleira nova', x: 0.4, y: 0.8 },
    ]);
    expect(result.createdAt).toBe('2026-08-08T12:00:00.000Z');

    // The nested create builds urls from the key and defaults positions to
    // the array index; captions are created alongside each image.
    const createArgs = (
      txMock.dogPost.create.mock.calls as unknown as [
        [
          {
            data: {
              images: {
                create: Array<{
                  url: string;
                  position: number;
                  captions: { create: unknown[] };
                }>;
              };
            };
          },
        ],
      ]
    )[0][0];
    expect(createArgs.data.images.create[0].url).toBe(
      `${PUBLIC_URL}/dogs/a.jpg`,
    );
    expect(createArgs.data.images.create[0].position).toBe(0);
    expect(createArgs.data.images.create[1].position).toBe(1);
    expect(createArgs.data.images.create[0].captions.create).toHaveLength(2);
    expect(createArgs.data.images.create[1].captions.create).toHaveLength(0);
  });

  it('rejects mutations from a user that does not own the dog with 403', async () => {
    prismaMock.dog.findUnique.mockResolvedValue(makeDog(OTHER_USER_ID));

    await expect(
      service.create(OWNER_ID, DOG_ID, {
        type: DogPostType.TEXT,
        text: 'Post invasor',
      }),
    ).rejects.toThrow(ForbiddenException);
    await expect(
      service.update(OWNER_ID, DOG_ID, POST_ID, { text: 'Novo texto' }),
    ).rejects.toThrow(ForbiddenException);
    await expect(service.remove(OWNER_ID, DOG_ID, POST_ID)).rejects.toThrow(
      ForbiddenException,
    );
    expect(prismaMock.dogPost.count).not.toHaveBeenCalled();
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
    expect(prismaMock.dogPost.delete).not.toHaveBeenCalled();
  });
});
