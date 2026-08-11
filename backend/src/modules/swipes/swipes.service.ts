import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Prisma, SwipeAction } from '@prisma/client';
import {
  MATCH_CREATED_EVENT,
  MatchCreatedEvent,
} from '../../common/events/app-events';
import { PrismaService } from '../../prisma/prisma.service';
import { toDogDto } from '../dogs/dog.mapper';
import {
  matchInclude,
  MatchWithRelations,
  toMatchDto,
} from '../matches/match.mapper';
import { CreateSwipeDto } from './dto/create-swipe.dto';
import { LikeReceivedDto, LikesReceivedDto } from './dto/likes-received.dto';
import { SwipeResultDto } from './dto/swipe-result.dto';

export const LIKES_RECEIVED_TAKE = 100;

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
    // A brand-new match has no messages; a re-LIKE returning a pre-existing
    // match may already carry unread history, so count it for real.
    const unreadCount = isNew
      ? 0
      : await this.prisma.message.count({
          where: { matchId: match.id, senderId: { not: userId }, readAt: null },
        });
    return {
      matched: true,
      match: toMatchDto(match, dto.swiperDogId, unreadCount),
    };
  }

  async likesReceived(
    userId: string,
    dogId: string,
  ): Promise<LikesReceivedDto> {
    const dog = await this.prisma.dog.findUnique({
      where: { id: dogId },
      include: { owner: true },
    });
    if (!dog) {
      throw new NotFoundException('Dog not found');
    }
    if (dog.ownerId !== userId) {
      throw new ForbiddenException('You do not own this dog');
    }

    // Pending like = LIKE toward this dog with no reciprocal LIKE from it and
    // no match for the pair. A PASS of mine must NOT hide the entry (the app
    // offers to revert it) — only a reciprocal LIKE excludes the liker.
    const where: Prisma.SwipeWhereInput = {
      targetDogId: dogId,
      action: SwipeAction.LIKE,
      swiperDog: {
        active: true,
        ownerId: { not: userId },
        swipesReceived: {
          none: { swiperDogId: dogId, action: SwipeAction.LIKE },
        },
        matchesAsA: { none: { dogBId: dogId } },
        matchesAsB: { none: { dogAId: dogId } },
      },
    };

    const [total, likes] = await Promise.all([
      this.prisma.swipe.count({ where }),
      this.prisma.swipe.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: LIKES_RECEIVED_TAKE,
        include: {
          swiperDog: {
            include: { photos: { orderBy: { position: 'asc' } }, owner: true },
          },
        },
      }),
    ]);
    if (likes.length === 0) {
      return { items: [], total };
    }

    const [myPasses, distanceKmByOwnerId] = await Promise.all([
      this.prisma.swipe.findMany({
        where: {
          swiperDogId: dogId,
          targetDogId: { in: likes.map((like) => like.swiperDogId) },
          action: SwipeAction.PASS,
        },
      }),
      this.distancesKmFrom(
        dog.owner,
        likes.map((like) => like.swiperDog.ownerId),
      ),
    ]);
    const passedDogIds = new Set(myPasses.map((swipe) => swipe.targetDogId));

    const items: LikeReceivedDto[] = likes.map((like) => ({
      dog: toDogDto(like.swiperDog),
      distanceKm: distanceKmByOwnerId.get(like.swiperDog.ownerId) ?? null,
      owner: {
        id: like.swiperDog.owner.id,
        name: like.swiperDog.owner.name,
        city: like.swiperDog.owner.city,
        avatarUrl: like.swiperDog.owner.avatarUrl,
      },
      likedAt: like.createdAt.toISOString(),
      myAction: passedDogIds.has(like.swiperDogId) ? 'PASS' : null,
    }));
    return { items, total };
  }

  private async distancesKmFrom(
    origin: { latitude: number | null; longitude: number | null },
    ownerIds: string[],
  ): Promise<Map<string, number>> {
    if (origin.latitude === null || origin.longitude === null) {
      return new Map();
    }
    const ids = [...new Set(ownerIds)];
    if (ids.length === 0) {
      return new Map();
    }
    const rows = await this.prisma.$queryRaw<
      Array<{ id: string; distance_m: number }>
    >(Prisma.sql`
      SELECT u.id, ST_Distance(
               ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography,
               ST_SetSRID(ST_MakePoint(${origin.longitude}, ${origin.latitude}), 4326)::geography
             ) AS distance_m
      FROM users u
      WHERE u.id::text IN (${Prisma.join(ids)})
        AND u.latitude IS NOT NULL AND u.longitude IS NOT NULL
    `);
    // Same 1-decimal km rounding as the discovery feed cards.
    return new Map(
      rows.map((row) => [row.id, Math.round(row.distance_m / 100) / 10]),
    );
  }
}
