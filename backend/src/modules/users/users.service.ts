import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { toDogDto } from '../dogs/dog.mapper';
import { OwnerProfileDto } from './dto/owner-profile.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { UserDto } from './dto/user.dto';
import { toUserDto } from './user.mapper';

const userInclude = {
  dogs: {
    include: { photos: { orderBy: { position: 'asc' as const } } },
    orderBy: { createdAt: 'asc' as const },
  },
};

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async me(userId: string): Promise<UserDto> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: userInclude,
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return toUserDto(user);
  }

  async updateMe(userId: string, dto: UpdateUserDto): Promise<UserDto> {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: dto,
      include: userInclude,
    });
    return toUserDto(user);
  }

  /**
   * Public owner profile. Privacy invariant: the response never contains
   * email, phone, latitude, longitude or any hashes — only the fields
   * explicitly mapped below.
   */
  async getOwnerProfile(
    requesterId: string,
    targetId: string,
  ): Promise<OwnerProfileDto> {
    const target = await this.prisma.user.findUnique({
      where: { id: targetId },
      include: {
        dogs: {
          where: { active: true },
          include: { photos: { orderBy: { position: 'asc' as const } } },
          orderBy: { createdAt: 'desc' as const },
        },
      },
    });
    if (!target) {
      throw new NotFoundException('User not found');
    }

    const [matches, distanceKm] = await Promise.all([
      this.countOwnerMatches(targetId),
      this.distanceToOwnerKm(requesterId, target),
    ]);

    return {
      id: target.id,
      name: target.name,
      bio: target.bio,
      avatarUrl: target.avatarUrl,
      city: target.city,
      memberSince: target.createdAt.toISOString(),
      distanceKm,
      stats: { dogs: target.dogs.length, matches },
      dogs: target.dogs.map(toDogDto),
    };
  }

  /** Matches involving any dog of the owner (active or not). */
  private async countOwnerMatches(ownerId: string): Promise<number> {
    const dogs = await this.prisma.dog.findMany({
      where: { ownerId },
      select: { id: true },
    });
    if (dogs.length === 0) {
      return 0;
    }
    const dogIds = dogs.map((dog) => dog.id);
    return this.prisma.match.count({
      where: {
        OR: [{ dogAId: { in: dogIds } }, { dogBId: { in: dogIds } }],
      },
    });
  }

  /**
   * Distance in km (1 decimal) between requester and target, or null when
   * the profile is the requester's own or either side has no location.
   */
  private async distanceToOwnerKm(
    requesterId: string,
    target: { id: string; latitude: number | null; longitude: number | null },
  ): Promise<number | null> {
    if (
      requesterId === target.id ||
      target.latitude === null ||
      target.longitude === null
    ) {
      return null;
    }
    const requester = await this.prisma.user.findUnique({
      where: { id: requesterId },
      select: { latitude: true, longitude: true },
    });
    if (
      !requester ||
      requester.latitude === null ||
      requester.longitude === null
    ) {
      return null;
    }
    const rows = await this.prisma.$queryRaw<Array<{ distance_m: number }>>(
      Prisma.sql`
        SELECT ST_Distance(
                 ST_SetSRID(ST_MakePoint(${target.longitude}, ${target.latitude}), 4326)::geography,
                 ST_SetSRID(ST_MakePoint(${requester.longitude}, ${requester.latitude}), 4326)::geography
               ) AS distance_m
      `,
    );
    const distanceM = rows[0]?.distance_m;
    return typeof distanceM === 'number'
      ? Math.round(distanceM / 100) / 10
      : null;
  }
}
