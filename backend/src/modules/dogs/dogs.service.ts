import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Dog, DogPhoto } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { toDogDto } from './dog.mapper';
import { AddDogPhotoDto } from './dto/add-dog-photo.dto';
import { CreateDogDto } from './dto/create-dog.dto';
import { DogDetailDto } from './dto/dog-detail.dto';
import { DogDto } from './dto/dog.dto';
import { UpdateDogDto } from './dto/update-dog.dto';

const MAX_PHOTOS_PER_DOG = 6;

@Injectable()
export class DogsService {
  private readonly publicUrl: string;

  constructor(
    private readonly prisma: PrismaService,
    config: ConfigService,
  ) {
    this.publicUrl = config.getOrThrow<string>('S3_PUBLIC_URL');
  }

  async findMine(userId: string): Promise<DogDto[]> {
    const dogs = await this.prisma.dog.findMany({
      where: { ownerId: userId },
      include: { photos: { orderBy: { position: 'asc' } } },
      orderBy: { createdAt: 'asc' },
    });
    return dogs.map(toDogDto);
  }

  async create(userId: string, dto: CreateDogDto): Promise<DogDto> {
    const birthDate = this.parseBirthDate(dto.birthDate);
    const dog = await this.prisma.dog.create({
      data: {
        ownerId: userId,
        name: dto.name,
        breed: dto.breed,
        sex: dto.sex,
        birthDate,
        size: dto.size,
        intent: dto.intent,
        bio: dto.bio,
        neutered: dto.neutered ?? false,
        pedigree: dto.pedigree ?? false,
      },
      include: { photos: true },
    });
    return toDogDto(dog);
  }

  async findOne(userId: string, dogId: string): Promise<DogDetailDto> {
    const dog = await this.prisma.dog.findUnique({
      where: { id: dogId },
      include: { photos: { orderBy: { position: 'asc' } }, owner: true },
    });
    if (!dog || (!dog.active && dog.ownerId !== userId)) {
      throw new NotFoundException('Dog not found');
    }
    return {
      ...toDogDto(dog),
      owner: {
        id: dog.owner.id,
        name: dog.owner.name,
        city: dog.owner.city,
        avatarUrl: dog.owner.avatarUrl,
      },
    };
  }

  async update(
    userId: string,
    dogId: string,
    dto: UpdateDogDto,
  ): Promise<DogDto> {
    await this.getOwnedDog(userId, dogId);
    const { birthDate, ...rest } = dto;
    const dog = await this.prisma.dog.update({
      where: { id: dogId },
      data: {
        ...rest,
        ...(birthDate !== undefined
          ? { birthDate: this.parseBirthDate(birthDate) }
          : {}),
      },
      include: { photos: { orderBy: { position: 'asc' } } },
    });
    return toDogDto(dog);
  }

  async remove(userId: string, dogId: string): Promise<void> {
    await this.getOwnedDog(userId, dogId);
    await this.prisma.dog.delete({ where: { id: dogId } });
  }

  async addPhoto(
    userId: string,
    dogId: string,
    dto: AddDogPhotoDto,
  ): Promise<DogPhoto> {
    await this.getOwnedDog(userId, dogId);
    const count = await this.prisma.dogPhoto.count({ where: { dogId } });
    if (count >= MAX_PHOTOS_PER_DOG) {
      throw new BadRequestException(
        `A dog can have at most ${MAX_PHOTOS_PER_DOG} photos`,
      );
    }
    return this.prisma.dogPhoto.create({
      data: {
        dogId,
        key: dto.key,
        url: `${this.publicUrl}/${dto.key}`,
        position: dto.position ?? count,
      },
    });
  }

  async removePhoto(
    userId: string,
    dogId: string,
    photoId: string,
  ): Promise<void> {
    await this.getOwnedDog(userId, dogId);
    const photo = await this.prisma.dogPhoto.findUnique({
      where: { id: photoId },
    });
    if (!photo || photo.dogId !== dogId) {
      throw new NotFoundException('Photo not found');
    }
    await this.prisma.dogPhoto.delete({ where: { id: photoId } });
  }

  private async getOwnedDog(userId: string, dogId: string): Promise<Dog> {
    const dog = await this.prisma.dog.findUnique({ where: { id: dogId } });
    if (!dog) {
      throw new NotFoundException('Dog not found');
    }
    if (dog.ownerId !== userId) {
      throw new ForbiddenException('You do not own this dog');
    }
    return dog;
  }

  private parseBirthDate(value: string): Date {
    const birthDate = new Date(value);
    if (birthDate.getTime() > Date.now()) {
      throw new BadRequestException('birthDate cannot be in the future');
    }
    return birthDate;
  }
}
