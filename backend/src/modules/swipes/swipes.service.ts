import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { SwipeAction } from '@prisma/client';
import {
  MATCH_CREATED_EVENT,
  MatchCreatedEvent,
} from '../../common/events/app-events';
import { PrismaService } from '../../prisma/prisma.service';
import {
  matchInclude,
  MatchWithRelations,
  toMatchDto,
} from '../matches/match.mapper';
import { CreateSwipeDto } from './dto/create-swipe.dto';
import { SwipeResultDto } from './dto/swipe-result.dto';

type SwipeTxResult =
  | { matched: false }
  | { matched: true; match: MatchWithRelations; isNew: boolean };

@Injectable()
export class SwipesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async swipe(userId: string, dto: CreateSwipeDto): Promise<SwipeResultDto> {
    if (dto.swiperDogId === dto.targetDogId) {
      throw new BadRequestException('A dog cannot swipe itself');
    }

    const result = await this.prisma.$transaction<SwipeTxResult>(async (tx) => {
      const swiperDog = await tx.dog.findUnique({
        where: { id: dto.swiperDogId },
      });
      if (!swiperDog) {
        throw new NotFoundException('Swiper dog not found');
      }
      if (swiperDog.ownerId !== userId) {
        throw new ForbiddenException('You do not own this dog');
      }
      const targetDog = await tx.dog.findUnique({
        where: { id: dto.targetDogId },
      });
      if (!targetDog || !targetDog.active) {
        throw new NotFoundException('Target dog not found');
      }
      if (targetDog.ownerId === userId) {
        throw new BadRequestException('You cannot swipe your own dog');
      }

      // Re-swipe overwrites the previous action AND refreshes createdAt
      // (ARCHITECTURE §3.6) — PASS → LIKE undoes an accidental pass. Not
      // obvious: repeating a PASS also renews createdAt, which restarts the
      // discovery feed cooldown window (PASS_COOLDOWN_DAYS).
      await tx.swipe.upsert({
        where: {
          swiperDogId_targetDogId: {
            swiperDogId: dto.swiperDogId,
            targetDogId: dto.targetDogId,
          },
        },
        create: {
          swiperDogId: dto.swiperDogId,
          targetDogId: dto.targetDogId,
          action: dto.action,
        },
        update: { action: dto.action, createdAt: new Date() },
      });

      if (dto.action !== SwipeAction.LIKE) {
        return { matched: false };
      }

      const reverse = await tx.swipe.findUnique({
        where: {
          swiperDogId_targetDogId: {
            swiperDogId: dto.targetDogId,
            targetDogId: dto.swiperDogId,
          },
        },
      });
      if (!reverse || reverse.action !== SwipeAction.LIKE) {
        return { matched: false };
      }

      // Runs on every swipe whose FINAL action is LIKE — including re-swipes
      // such as PASS → LIKE. When the pair already matched before, the match
      // is returned as-is instead of re-created (unique dogAId+dogBId).
      const [dogAId, dogBId] = [dto.swiperDogId, dto.targetDogId].sort();
      const existing = await tx.match.findUnique({
        where: { dogAId_dogBId: { dogAId, dogBId } },
        include: matchInclude,
      });
      if (existing) {
        return { matched: true, match: existing, isNew: false };
      }
      const created = await tx.match.create({
        data: { dogAId, dogBId },
        include: matchInclude,
      });
      return { matched: true, match: created, isNew: true };
    });

    if (!result.matched) {
      return { matched: false };
    }

    const { match, isNew } = result;
    if (isNew) {
      const event: MatchCreatedEvent = {
        matchId: match.id,
        recipients: [
          {
            userId: match.dogA.ownerId,
            match: toMatchDto(match, match.dogA.id),
          },
          {
            userId: match.dogB.ownerId,
            match: toMatchDto(match, match.dogB.id),
          },
        ],
      };
      this.eventEmitter.emit(MATCH_CREATED_EVENT, event);
    }
    return { matched: true, match: toMatchDto(match, dto.swiperDogId) };
  }
}
