import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Dog, DogPost, DogPostType, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { dogPostInclude, toDogPostDto } from './dog-post.mapper';
import { CreateDogPostDto } from './dto/create-dog-post.dto';
import type { CreateDogPostImageDto } from './dto/create-dog-post.dto';
import { DogPostDto } from './dto/dog-post.dto';
import { UpdateDogPostDto } from './dto/update-dog-post.dto';

const MAX_POSTS_PER_DOG = 10;
const MIN_CAROUSEL_IMAGES = 2;
const MAX_CAROUSEL_IMAGES = 8;

@Injectable()
export class DogPostsService {
  private readonly publicUrl: string;

  constructor(
    private readonly prisma: PrismaService,
    config: ConfigService,
  ) {
    this.publicUrl = config.getOrThrow<string>('S3_PUBLIC_URL');
  }

  async findAll(userId: string, dogId: string): Promise<DogPostDto[]> {
    const dog = await this.prisma.dog.findUnique({ where: { id: dogId } });
    if (!dog || (!dog.active && dog.ownerId !== userId)) {
      throw new NotFoundException('Dog not found');
    }
    const posts = await this.prisma.dogPost.findMany({
      where: { dogId },
      include: dogPostInclude,
      orderBy: { createdAt: 'desc' },
    });
    return posts.map(toDogPostDto);
  }

  async create(
    userId: string,
    dogId: string,
    dto: CreateDogPostDto,
  ): Promise<DogPostDto> {
    await this.getOwnedDog(userId, dogId);
    const count = await this.prisma.dogPost.count({ where: { dogId } });
    if (count >= MAX_POSTS_PER_DOG) {
      throw new BadRequestException('POST_LIMIT_REACHED');
    }
    const images = dto.images ?? [];
    this.validateContentForType(dto.type, dto.text, images);

    const post = await this.prisma.$transaction((tx) =>
      tx.dogPost.create({
        data: {
          dogId,
          type: dto.type,
          text: dto.text ?? null,
          images: { create: this.buildImagesCreateInput(images) },
        },
        include: dogPostInclude,
      }),
    );
    return toDogPostDto(post);
  }

  /**
   * Replaces the post content (text/images/captions) keeping its ORIGINAL
   * type: the new content is revalidated against that type. Images and
   * captions are recreated inside a transaction (DB cascade removes the
   * captions of the deleted images).
   */
  async update(
    userId: string,
    dogId: string,
    postId: string,
    dto: UpdateDogPostDto,
  ): Promise<DogPostDto> {
    await this.getOwnedDog(userId, dogId);
    const post = await this.getPostOfDog(dogId, postId);
    const images = dto.images ?? [];
    this.validateContentForType(post.type, dto.text, images);

    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.dogPostImage.deleteMany({ where: { postId } });
      return tx.dogPost.update({
        where: { id: postId },
        data: {
          text: dto.text ?? null,
          images: { create: this.buildImagesCreateInput(images) },
        },
        include: dogPostInclude,
      });
    });
    return toDogPostDto(updated);
  }

  async remove(userId: string, dogId: string, postId: string): Promise<void> {
    await this.getOwnedDog(userId, dogId);
    await this.getPostOfDog(dogId, postId);
    await this.prisma.dogPost.delete({ where: { id: postId } });
  }

  /** Rules from ARCHITECTURE §3.5.2 (per post type). */
  private validateContentForType(
    type: DogPostType,
    text: string | undefined,
    images: CreateDogPostImageDto[],
  ): void {
    switch (type) {
      case DogPostType.TEXT:
        if (text === undefined) {
          throw new BadRequestException('TEXT posts require text');
        }
        if (images.length > 0) {
          throw new BadRequestException('TEXT posts cannot have images');
        }
        break;
      case DogPostType.IMAGE:
        if (text !== undefined) {
          throw new BadRequestException('IMAGE posts cannot have text');
        }
        if (images.length !== 1) {
          throw new BadRequestException('IMAGE posts require exactly 1 image');
        }
        break;
      case DogPostType.IMAGE_TEXT:
        if (text === undefined) {
          throw new BadRequestException('IMAGE_TEXT posts require text');
        }
        if (images.length !== 1) {
          throw new BadRequestException(
            'IMAGE_TEXT posts require exactly 1 image',
          );
        }
        break;
      case DogPostType.CAROUSEL:
        if (
          images.length < MIN_CAROUSEL_IMAGES ||
          images.length > MAX_CAROUSEL_IMAGES
        ) {
          throw new BadRequestException(
            `CAROUSEL posts require between ${MIN_CAROUSEL_IMAGES} and ${MAX_CAROUSEL_IMAGES} images`,
          );
        }
        break;
    }
  }

  /** Image URL is always built on the server from the key (never trusted from the client). */
  private buildImagesCreateInput(
    images: CreateDogPostImageDto[],
  ): Prisma.DogPostImageCreateWithoutPostInput[] {
    return images.map((image, index) => ({
      key: image.key,
      url: `${this.publicUrl}/${image.key}`,
      position: image.position ?? index,
      captions: {
        create: (image.captions ?? []).map((caption) => ({
          text: caption.text,
          x: caption.x,
          y: caption.y,
        })),
      },
    }));
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

  private async getPostOfDog(dogId: string, postId: string): Promise<DogPost> {
    const post = await this.prisma.dogPost.findUnique({
      where: { id: postId },
    });
    if (!post || post.dogId !== dogId) {
      throw new NotFoundException('Post not found');
    }
    return post;
  }
}
