import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Dog, Match } from '@prisma/client';
import {
  MESSAGE_CREATED_EVENT,
  MessageCreatedEvent,
} from '../../common/events/app-events';
import { PrismaService } from '../../prisma/prisma.service';
import { MatchDto } from './dto/match.dto';
import { MessageDto } from './dto/message.dto';
import { MessagesPageDto } from './dto/messages-page.dto';
import { matchInclude, toMatchDto, toMessageDto } from './match.mapper';

type MatchWithDogs = Match & { dogA: Dog; dogB: Dog };

@Injectable()
export class MatchesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async list(userId: string, dogId: string): Promise<MatchDto[]> {
    const dog = await this.prisma.dog.findUnique({ where: { id: dogId } });
    if (!dog) {
      throw new NotFoundException('Dog not found');
    }
    if (dog.ownerId !== userId) {
      throw new ForbiddenException('You do not own this dog');
    }
    const matches = await this.prisma.match.findMany({
      where: { OR: [{ dogAId: dogId }, { dogBId: dogId }] },
      include: matchInclude,
      orderBy: { createdAt: 'desc' },
    });
    if (matches.length === 0) {
      return [];
    }
    // Single aggregated query for the whole page — never one count per match.
    const unreadRows = await this.prisma.message.groupBy({
      by: ['matchId'],
      where: {
        matchId: { in: matches.map((match) => match.id) },
        senderId: { not: userId },
        readAt: null,
      },
      _count: { _all: true },
    });
    const unreadByMatchId = new Map(
      unreadRows.map((row) => [row.matchId, row._count._all]),
    );
    return matches.map((match) =>
      toMatchDto(match, dogId, unreadByMatchId.get(match.id) ?? 0),
    );
  }

  async markRead(userId: string, matchId: string): Promise<void> {
    await this.getMatchForUser(userId, matchId);
    await this.prisma.message.updateMany({
      where: { matchId, senderId: { not: userId }, readAt: null },
      data: { readAt: new Date() },
    });
  }

  async getMessages(
    userId: string,
    matchId: string,
    cursor: string | undefined,
    limit: number,
  ): Promise<MessagesPageDto> {
    await this.getMatchForUser(userId, matchId);
    const messages = await this.prisma.message.findMany({
      where: { matchId },
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    const hasMore = messages.length > limit;
    const items = hasMore ? messages.slice(0, limit) : messages;
    const page: MessagesPageDto = { items: items.map(toMessageDto) };
    if (hasMore && items.length > 0) {
      page.nextCursor = items[items.length - 1].id;
    }
    return page;
  }

  async createMessage(
    userId: string,
    matchId: string,
    content: string,
  ): Promise<MessageDto> {
    const trimmed = content?.trim();
    if (!trimmed) {
      throw new BadRequestException('content must not be empty');
    }
    const match = await this.getMatchForUser(userId, matchId);
    const message = await this.prisma.message.create({
      data: { matchId, senderId: userId, content: trimmed },
    });
    const dto = toMessageDto(message);
    const recipientUserId =
      match.dogA.ownerId === userId ? match.dogB.ownerId : match.dogA.ownerId;
    const event: MessageCreatedEvent = {
      matchId,
      senderUserId: userId,
      recipientUserId,
      message: dto,
    };
    this.eventEmitter.emit(MESSAGE_CREATED_EVENT, event);
    return dto;
  }

  async isParticipant(userId: string, matchId: string): Promise<boolean> {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: { dogA: true, dogB: true },
    });
    return (
      !!match &&
      (match.dogA.ownerId === userId || match.dogB.ownerId === userId)
    );
  }

  private async getMatchForUser(
    userId: string,
    matchId: string,
  ): Promise<MatchWithDogs> {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: { dogA: true, dogB: true },
    });
    if (!match) {
      throw new NotFoundException('Match not found');
    }
    if (match.dogA.ownerId !== userId && match.dogB.ownerId !== userId) {
      throw new ForbiddenException('You are not part of this match');
    }
    return match;
  }
}
