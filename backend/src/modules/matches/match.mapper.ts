import { Match, Message, User } from '@prisma/client';
import { DogWithPhotos, toDogDto } from '../dogs/dog.mapper';
import { MatchDto } from './dto/match.dto';
import { MessageDto } from './dto/message.dto';

export type DogWithPhotosAndOwner = DogWithPhotos & { owner: User };

export type MatchWithRelations = Match & {
  dogA: DogWithPhotosAndOwner;
  dogB: DogWithPhotosAndOwner;
  messages: Message[];
};

export const matchInclude = {
  dogA: {
    include: { photos: { orderBy: { position: 'asc' as const } }, owner: true },
  },
  dogB: {
    include: { photos: { orderBy: { position: 'asc' as const } }, owner: true },
  },
  messages: { orderBy: { createdAt: 'desc' as const }, take: 1 },
};

export function toMessageDto(message: Message): MessageDto {
  return {
    id: message.id,
    matchId: message.matchId,
    senderId: message.senderId,
    content: message.content,
    createdAt: message.createdAt.toISOString(),
    readAt: message.readAt ? message.readAt.toISOString() : null,
  };
}

export function toMatchDto(
  match: MatchWithRelations,
  myDogId: string,
): MatchDto {
  const myDog = match.dogA.id === myDogId ? match.dogA : match.dogB;
  const otherDog = match.dogA.id === myDogId ? match.dogB : match.dogA;
  const lastMessage = match.messages[0];
  return {
    id: match.id,
    createdAt: match.createdAt.toISOString(),
    myDog: toDogDto(myDog),
    otherDog: toDogDto(otherDog),
    otherOwner: {
      id: otherDog.owner.id,
      name: otherDog.owner.name,
      avatarUrl: otherDog.owner.avatarUrl,
    },
    lastMessage: lastMessage ? toMessageDto(lastMessage) : null,
  };
}
