import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DogIntent, DogSex, Prisma, SwipeAction } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { toDogDto } from '../dogs/dog.mapper';
import { DiscoveryCardDto } from './dto/discovery-card.dto';
import { DiscoveryQueryDto } from './dto/discovery-query.dto';
import { SearchDogsQueryDto, SearchOrderBy } from './dto/search-dogs-query.dto';
import { SearchCardDto, SearchResultDto } from './dto/search-result.dto';

/**
 * Feed exclusion by swipe state (ARCHITECTURE §3.5): a LIKE hides the target
 * from the deck for good; a PASS only hides it for this many days, so passed
 * dogs come back to the feed once the window expires. Re-swipes refresh the
 * swipe's createdAt (§3.6), which restarts this window.
 */
export const PASS_COOLDOWN_DAYS = 7;

interface DiscoveryRow {
  id: string;
  distance_m: number;
}

interface SearchRow {
  id: string;
  distance_m: number | null;
}

@Injectable()
export class DiscoveryService {
  constructor(private readonly prisma: PrismaService) {}

  async discover(
    userId: string,
    query: DiscoveryQueryDto,
  ): Promise<DiscoveryCardDto[]> {
    const dog = await this.prisma.dog.findUnique({
      where: { id: query.dogId },
      include: { owner: true },
    });
    if (!dog) {
      throw new NotFoundException('Dog not found');
    }
    if (dog.ownerId !== userId) {
      throw new ForbiddenException('You do not own this dog');
    }
    const { latitude, longitude } = dog.owner;
    if (latitude === null || longitude === null) {
      throw new BadRequestException('LOCATION_REQUIRED');
    }

    const radiusM = (query.radiusKm ?? 50) * 1000;
    const limit = query.limit ?? 20;

    const oppositeSex: DogSex =
      dog.sex === DogSex.MALE ? DogSex.FEMALE : DogSex.MALE;
    const breedingClause = Prisma.sql`(d.intent::text IN ('BREEDING', 'BOTH') AND d.sex::text = ${oppositeSex} AND d.neutered = false)`;
    const friendshipClause = Prisma.sql`(d.intent::text IN ('FRIENDSHIP', 'BOTH'))`;
    const intentClause =
      dog.intent === DogIntent.BREEDING
        ? breedingClause
        : dog.intent === DogIntent.FRIENDSHIP
          ? friendshipClause
          : Prisma.sql`(${breedingClause} OR ${friendshipClause})`;

    const rows = await this.prisma.$queryRaw<DiscoveryRow[]>(Prisma.sql`
      SELECT d.id, ST_Distance(
               ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography,
               ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography
             ) AS distance_m
      FROM dogs d
      JOIN users u ON u.id = d.owner_id
      WHERE d.active = true
        AND d.owner_id <> ${userId}::uuid
        AND u.latitude IS NOT NULL AND u.longitude IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM swipes s
                        WHERE s.swiper_dog_id = ${query.dogId}::uuid
                          AND s.target_dog_id = d.id
                          AND (s.action::text = 'LIKE'
                               OR (s.action::text = 'PASS'
                                   AND s.created_at > now() - make_interval(days => ${PASS_COOLDOWN_DAYS}::int))))
        AND ST_DWithin(
              ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography,
              ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography,
              ${radiusM})
        AND ${intentClause}
      ORDER BY distance_m ASC
      LIMIT ${limit}
    `);

    if (rows.length === 0) {
      return [];
    }

    const dogs = await this.prisma.dog.findMany({
      where: { id: { in: rows.map((row) => row.id) } },
      include: { photos: { orderBy: { position: 'asc' } }, owner: true },
    });
    const dogsById = new Map(
      dogs.map((candidate) => [candidate.id, candidate]),
    );

    const cards: DiscoveryCardDto[] = [];
    for (const row of rows) {
      const candidate = dogsById.get(row.id);
      if (!candidate) {
        continue;
      }
      cards.push({
        dog: toDogDto(candidate),
        distanceKm: Math.round(row.distance_m / 100) / 10,
        owner: {
          id: candidate.owner.id,
          name: candidate.owner.name,
          city: candidate.owner.city,
          avatarUrl: candidate.owner.avatarUrl,
        },
      });
    }
    return cards;
  }

  async search(
    userId: string,
    query: SearchDogsQueryDto,
  ): Promise<SearchResultDto> {
    if (query.excludeSwiped && !query.dogId) {
      throw new BadRequestException(
        'excludeSwiped requires dogId to be provided',
      );
    }
    if (
      query.ageMinYears !== undefined &&
      query.ageMaxYears !== undefined &&
      query.ageMinYears > query.ageMaxYears
    ) {
      throw new BadRequestException(
        'ageMinYears must be less than or equal to ageMaxYears',
      );
    }
    if (query.dogId) {
      const perspectiveDog = await this.prisma.dog.findUnique({
        where: { id: query.dogId },
      });
      if (!perspectiveDog) {
        throw new NotFoundException('Dog not found');
      }
      if (perspectiveDog.ownerId !== userId) {
        throw new ForbiddenException('You do not own this dog');
      }
    }

    const me = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!me) {
      throw new NotFoundException('User not found');
    }
    const { latitude, longitude } = me;
    const hasLocation = latitude !== null && longitude !== null;
    if (
      (query.radiusKm !== undefined || query.orderBy === 'distance') &&
      !hasLocation
    ) {
      throw new BadRequestException('LOCATION_REQUIRED');
    }

    const orderBy: SearchOrderBy =
      query.orderBy ?? (hasLocation ? 'distance' : 'recent');
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const now = new Date();

    const clauses: Prisma.Sql[] = [Prisma.sql`d.active = true`];
    if (query.q !== undefined) {
      const pattern = `%${query.q}%`;
      clauses.push(
        Prisma.sql`(d.name ILIKE ${pattern} OR d.breed ILIKE ${pattern})`,
      );
    }
    if (query.sex !== undefined) {
      clauses.push(Prisma.sql`d.sex::text = ${query.sex}`);
    }
    if (query.size !== undefined && query.size.length > 0) {
      clauses.push(Prisma.sql`d.size::text IN (${Prisma.join(query.size)})`);
    }
    if (query.intent === DogIntent.BREEDING) {
      clauses.push(Prisma.sql`d.intent::text IN ('BREEDING', 'BOTH')`);
    } else if (query.intent === DogIntent.FRIENDSHIP) {
      clauses.push(Prisma.sql`d.intent::text IN ('FRIENDSHIP', 'BOTH')`);
    }
    if (query.ageMinYears !== undefined) {
      // At least N full years old: born on or before (now - N years).
      clauses.push(
        Prisma.sql`d.birth_date <= ${this.subtractYears(now, query.ageMinYears)}`,
      );
    }
    if (query.ageMaxYears !== undefined) {
      // At most N full years old: born strictly after (now - (N + 1) years).
      clauses.push(
        Prisma.sql`d.birth_date > ${this.subtractYears(now, query.ageMaxYears + 1)}`,
      );
    }
    if (query.neutered !== undefined) {
      clauses.push(Prisma.sql`d.neutered = ${query.neutered}`);
    }
    if (query.pedigree !== undefined) {
      clauses.push(Prisma.sql`d.pedigree = ${query.pedigree}`);
    }
    if (query.radiusKm !== undefined && hasLocation) {
      // Also filters out targets without location (ST_DWithin over NULL is not true).
      clauses.push(Prisma.sql`ST_DWithin(
        ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography,
        ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography,
        ${query.radiusKm * 1000})`);
    }
    if (query.excludeSwiped && query.dogId) {
      clauses.push(Prisma.sql`NOT EXISTS (SELECT 1 FROM swipes s
        WHERE s.swiper_dog_id = ${query.dogId}::uuid
          AND s.target_dog_id = d.id)`);
    }
    const whereClause = Prisma.join(clauses, ' AND ');

    const countRows = await this.prisma.$queryRaw<Array<{ count: number }>>(
      Prisma.sql`
        SELECT COUNT(*)::int AS count
        FROM dogs d
        JOIN users u ON u.id = d.owner_id
        WHERE ${whereClause}
      `,
    );
    const total = countRows[0]?.count ?? 0;
    const pageCount = Math.ceil(total / limit);
    if (total === 0) {
      return { items: [], total, page, pageCount };
    }

    // Distance is only computed when both sides have a location (CASE WHEN);
    // targets without location still show up (distanceKm null) unless radiusKm
    // filtered them out above.
    const distanceSelect = hasLocation
      ? Prisma.sql`CASE
          WHEN u.latitude IS NOT NULL AND u.longitude IS NOT NULL THEN ST_Distance(
            ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography,
            ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography)
          ELSE NULL
        END`
      : Prisma.sql`CAST(NULL AS double precision)`;
    const orderClause =
      orderBy === 'distance'
        ? Prisma.sql`distance_m ASC NULLS LAST, d.created_at DESC`
        : Prisma.sql`d.created_at DESC`;

    const rows = await this.prisma.$queryRaw<SearchRow[]>(Prisma.sql`
      SELECT d.id, ${distanceSelect} AS distance_m
      FROM dogs d
      JOIN users u ON u.id = d.owner_id
      WHERE ${whereClause}
      ORDER BY ${orderClause}
      LIMIT ${limit} OFFSET ${(page - 1) * limit}
    `);

    const ids = rows.map((row) => row.id);
    const dogs =
      ids.length > 0
        ? await this.prisma.dog.findMany({
            where: { id: { in: ids } },
            include: { photos: { orderBy: { position: 'asc' } }, owner: true },
          })
        : [];
    const dogsById = new Map(
      dogs.map((candidate) => [candidate.id, candidate]),
    );

    let actionByDogId: Map<string, SwipeAction> | undefined;
    let matchedDogIds: Set<string> | undefined;
    if (query.dogId && ids.length > 0) {
      const dogId = query.dogId;
      const [swipes, matches] = await Promise.all([
        this.prisma.swipe.findMany({
          where: { swiperDogId: dogId, targetDogId: { in: ids } },
        }),
        this.prisma.match.findMany({
          where: {
            OR: [
              { dogAId: dogId, dogBId: { in: ids } },
              { dogBId: dogId, dogAId: { in: ids } },
            ],
          },
        }),
      ]);
      actionByDogId = new Map(
        swipes.map((swipe) => [swipe.targetDogId, swipe.action]),
      );
      matchedDogIds = new Set(
        matches.map((match) =>
          match.dogAId === dogId ? match.dogBId : match.dogAId,
        ),
      );
    }

    const items: SearchCardDto[] = [];
    for (const row of rows) {
      const candidate = dogsById.get(row.id);
      if (!candidate) {
        continue;
      }
      const card: SearchCardDto = {
        dog: toDogDto(candidate),
        distanceKm:
          typeof row.distance_m === 'number'
            ? Math.round(row.distance_m / 100) / 10
            : null,
        owner: {
          id: candidate.owner.id,
          name: candidate.owner.name,
          city: candidate.owner.city,
          avatarUrl: candidate.owner.avatarUrl,
        },
        isMine: candidate.ownerId === userId,
      };
      if (query.dogId && !card.isMine) {
        card.myAction = actionByDogId?.get(row.id) ?? null;
        card.matched = matchedDogIds?.has(row.id) ?? false;
      }
      items.push(card);
    }
    return { items, total, page, pageCount };
  }

  private subtractYears(from: Date, years: number): Date {
    const result = new Date(from);
    result.setUTCFullYear(result.getUTCFullYear() - years);
    return result;
  }
}
