import {
  DogIntent,
  DogPostType,
  DogSex,
  DogSize,
  PrismaClient,
  SwipeAction,
} from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

const DEMO_EMAILS = ['ana@demo.com', 'bruno@demo.com', 'carla@demo.com'];

const placedog = (id: number): string =>
  `https://placedog.net/640/640?id=${id}`;

async function main(): Promise<void> {
  const passwordHash = await argon2.hash('Senha123!');

  // Idempotency: remove demo users (cascades to dogs, photos, swipes,
  // matches and messages) and recreate everything from scratch.
  await prisma.user.deleteMany({ where: { email: { in: DEMO_EMAILS } } });

  const ana = await prisma.user.create({
    data: {
      email: 'ana@demo.com',
      passwordHash,
      name: 'Ana Souza',
      phone: '+55 11 91234-0001',
      bio: 'Apaixonada por cachorros e trilhas aos fins de semana.',
      avatarUrl: 'https://i.pravatar.cc/300?img=5',
      city: 'São Paulo - Pinheiros',
      latitude: -23.5629,
      longitude: -46.6825,
    },
  });
  const bruno = await prisma.user.create({
    data: {
      email: 'bruno@demo.com',
      passwordHash,
      name: 'Bruno Lima',
      phone: '+55 11 91234-0002',
      bio: 'Pai de dois cachorros, sempre no parque do Ibirapuera.',
      avatarUrl: 'https://i.pravatar.cc/300?img=12',
      city: 'São Paulo - Moema',
      latitude: -23.6015,
      longitude: -46.6659,
    },
  });
  const carla = await prisma.user.create({
    data: {
      email: 'carla@demo.com',
      passwordHash,
      name: 'Carla Menezes',
      phone: '+55 11 91234-0003',
      bio: 'Adotei dois SRDs e não me arrependo de nada.',
      avatarUrl: 'https://i.pravatar.cc/300?img=9',
      city: 'São Paulo - Tatuapé',
      latitude: -23.5405,
      longitude: -46.5762,
    },
  });

  const thor = await prisma.dog.create({
    data: {
      ownerId: ana.id,
      name: 'Thor',
      breed: 'Golden Retriever',
      sex: DogSex.MALE,
      birthDate: new Date('2021-03-10T00:00:00.000Z'),
      size: DogSize.LARGE,
      intent: DogIntent.BOTH,
      bio: 'Bonzinho, adora água, bola e crianças.',
      neutered: false,
      pedigree: true,
      photos: {
        create: [
          { key: placedog(1), url: placedog(1), position: 0 },
          { key: placedog(2), url: placedog(2), position: 1 },
        ],
      },
    },
  });
  const luna = await prisma.dog.create({
    data: {
      ownerId: ana.id,
      name: 'Luna',
      breed: 'Poodle',
      sex: DogSex.FEMALE,
      birthDate: new Date('2019-07-22T00:00:00.000Z'),
      size: DogSize.SMALL,
      intent: DogIntent.FRIENDSHIP,
      bio: 'Tímida no começo, mas gruda em quem dá petisco.',
      neutered: true,
      pedigree: false,
      socialInstagram: '@luna.poodle',
      socialTelegram: '@lunapoodle',
      photos: { create: [{ key: placedog(3), url: placedog(3), position: 0 }] },
    },
  });
  const mel = await prisma.dog.create({
    data: {
      ownerId: bruno.id,
      name: 'Mel',
      breed: 'Labrador Retriever',
      sex: DogSex.FEMALE,
      birthDate: new Date('2020-11-05T00:00:00.000Z'),
      size: DogSize.LARGE,
      intent: DogIntent.BREEDING,
      bio: 'Labradora dócil com pedigree, procura um bom par.',
      neutered: false,
      pedigree: true,
      photos: {
        create: [
          { key: placedog(4), url: placedog(4), position: 0 },
          { key: placedog(5), url: placedog(5), position: 1 },
        ],
      },
    },
  });
  const rex = await prisma.dog.create({
    data: {
      ownerId: bruno.id,
      name: 'Rex',
      breed: 'Bulldog Francês',
      sex: DogSex.MALE,
      birthDate: new Date('2022-01-15T00:00:00.000Z'),
      size: DogSize.SMALL,
      intent: DogIntent.FRIENDSHIP,
      bio: 'Ronca alto e ama socializar na pracinha.',
      neutered: true,
      pedigree: false,
      socialWhatsapp: '+55 11 91234-0002',
      socialInstagram: '@rex.bulldog',
      photos: { create: [{ key: placedog(6), url: placedog(6), position: 0 }] },
    },
  });
  const nina = await prisma.dog.create({
    data: {
      ownerId: carla.id,
      name: 'Nina',
      breed: 'Shih Tzu',
      sex: DogSex.FEMALE,
      birthDate: new Date('2021-09-30T00:00:00.000Z'),
      size: DogSize.SMALL,
      intent: DogIntent.BOTH,
      bio: 'Pequena, vaidosa e cheia de energia.',
      neutered: false,
      pedigree: false,
      photos: {
        create: [
          { key: placedog(7), url: placedog(7), position: 0 },
          { key: placedog(8), url: placedog(8), position: 1 },
        ],
      },
    },
  });
  const bob = await prisma.dog.create({
    data: {
      ownerId: carla.id,
      name: 'Bob',
      breed: 'SRD (vira-lata)',
      sex: DogSex.MALE,
      birthDate: new Date('2018-05-01T00:00:00.000Z'),
      size: DogSize.MEDIUM,
      intent: DogIntent.FRIENDSHIP,
      bio: 'Veterano do bairro, amigo de todos os porteiros.',
      neutered: true,
      pedigree: false,
      photos: { create: [{ key: placedog(9), url: placedog(9), position: 0 }] },
    },
  });
  const amora = await prisma.dog.create({
    data: {
      ownerId: bruno.id,
      name: 'Amora',
      breed: 'Golden Retriever',
      sex: DogSex.FEMALE,
      birthDate: new Date('2025-06-20T00:00:00.000Z'),
      size: DogSize.LARGE,
      intent: DogIntent.FRIENDSHIP,
      bio: 'Filhote elétrica que aprende qualquer truque por petisco.',
      neutered: false,
      pedigree: false,
      photos: {
        create: [{ key: placedog(10), url: placedog(10), position: 0 }],
      },
    },
  });
  const pipoca = await prisma.dog.create({
    data: {
      ownerId: carla.id,
      name: 'Pipoca',
      breed: 'Poodle',
      sex: DogSex.MALE,
      birthDate: new Date('2019-04-12T00:00:00.000Z'),
      size: DogSize.SMALL,
      intent: DogIntent.BOTH,
      bio: 'Sete anos de pura elegância; castrado e muito sociável.',
      neutered: true,
      pedigree: false,
      photos: {
        create: [{ key: placedog(11), url: placedog(11), position: 0 }],
      },
    },
  });
  const maya = await prisma.dog.create({
    data: {
      ownerId: ana.id,
      name: 'Maya',
      breed: 'Border Collie',
      sex: DogSex.FEMALE,
      birthDate: new Date('2023-02-25T00:00:00.000Z'),
      size: DogSize.MEDIUM,
      intent: DogIntent.BREEDING,
      bio: 'Border com pedigree, campeã de agility no quintal.',
      neutered: false,
      pedigree: true,
      photos: {
        create: [
          { key: placedog(12), url: placedog(12), position: 0 },
          { key: placedog(13), url: placedog(13), position: 1 },
        ],
      },
    },
  });
  const zeus = await prisma.dog.create({
    data: {
      ownerId: carla.id,
      name: 'Zeus',
      breed: 'Labrador Retriever',
      sex: DogSex.MALE,
      birthDate: new Date('2021-06-15T00:00:00.000Z'),
      size: DogSize.LARGE,
      intent: DogIntent.BOTH,
      bio: 'Grandalhão manso que se acha cachorro de colo.',
      neutered: false,
      pedigree: false,
      photos: {
        create: [{ key: placedog(14), url: placedog(14), position: 0 }],
      },
    },
  });

  // Rex's dog page: one post of each flavor (TEXT with light markup,
  // IMAGE_TEXT, CAROUSEL with positioned captions). Newest first in the app.
  const daysAgo = (n: number): Date =>
    new Date(Date.now() - n * 24 * 60 * 60_000);
  await prisma.dogPost.create({
    data: {
      dogId: rex.id,
      type: DogPostType.TEXT,
      text: '**Rex** adora __parques__ e ~~gatos~~ petiscos',
      createdAt: daysAgo(3),
    },
  });
  await prisma.dogPost.create({
    data: {
      dogId: rex.id,
      type: DogPostType.IMAGE_TEXT,
      text: 'Primeiro banho de piscina do verão — `nota 10` em estilo!',
      createdAt: daysAgo(2),
      images: {
        create: [{ key: placedog(15), url: placedog(15), position: 0 }],
      },
    },
  });
  await prisma.dogPost.create({
    data: {
      dogId: rex.id,
      type: DogPostType.CAROUSEL,
      text: 'Melhores momentos do rolê no parque 🐾',
      createdAt: daysAgo(1),
      images: {
        create: [
          {
            key: placedog(16),
            url: placedog(16),
            position: 0,
            captions: {
              create: [
                { text: 'Cicatriz da aventura de 2024', x: 0.7, y: 0.3 },
                { text: 'Coleira nova, presente da vovó', x: 0.4, y: 0.8 },
              ],
            },
          },
          { key: placedog(17), url: placedog(17), position: 1 },
          {
            key: placedog(18),
            url: placedog(18),
            position: 2,
            captions: {
              create: [{ text: 'Cansado depois de 2h de bola', x: 0.5, y: 0.5 }],
            },
          },
        ],
      },
    },
  });

  await prisma.swipe.createMany({
    data: [
      { swiperDogId: thor.id, targetDogId: mel.id, action: SwipeAction.LIKE },
      { swiperDogId: mel.id, targetDogId: thor.id, action: SwipeAction.LIKE },
      { swiperDogId: luna.id, targetDogId: rex.id, action: SwipeAction.PASS },
      { swiperDogId: nina.id, targetDogId: rex.id, action: SwipeAction.LIKE },
      { swiperDogId: bob.id, targetDogId: luna.id, action: SwipeAction.LIKE },
    ],
  });

  // Mutual like between Thor (Ana) and Mel (Bruno) => match already formed.
  const [dogAId, dogBId] = [thor.id, mel.id].sort();
  const match = await prisma.match.create({ data: { dogAId, dogBId } });

  const now = Date.now();
  const minutes = (n: number): Date => new Date(now - n * 60_000);
  await prisma.message.create({
    data: {
      matchId: match.id,
      senderId: ana.id,
      content: 'Oi! O Thor adorou a Mel 🐶',
      createdAt: minutes(30),
    },
  });
  await prisma.message.create({
    data: {
      matchId: match.id,
      senderId: bruno.id,
      content: 'Olá! A Mel também curtiu o Thor. Bora marcar no parque?',
      createdAt: minutes(20),
    },
  });
  await prisma.message.create({
    data: {
      matchId: match.id,
      senderId: ana.id,
      content: 'Perfeito! Sábado no Villa-Lobos às 10h?',
      createdAt: minutes(10),
    },
  });
  await prisma.message.create({
    data: {
      matchId: match.id,
      senderId: bruno.id,
      content: 'Fechado, até sábado! 🐾',
      createdAt: minutes(5),
    },
  });

  console.log('Seed completed:');
  console.log(`  users: ${[ana, bruno, carla].map((u) => u.email).join(', ')}`);
  console.log(
    `  dogs: ${[thor, luna, mel, rex, nina, bob, amora, pipoca, maya, zeus]
      .map((d) => d.name)
      .join(', ')}`,
  );
  console.log(`  match Thor x Mel: ${match.id}`);
  console.log('  dog page: 3 posts on Rex (TEXT, IMAGE_TEXT, CAROUSEL)');
  console.log('  social links: Rex (whatsapp+instagram), Luna (instagram+telegram)');
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
