import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
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
}
