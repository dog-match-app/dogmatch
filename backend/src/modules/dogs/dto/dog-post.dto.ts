import { ApiProperty } from '@nestjs/swagger';
import { DogPostType } from '@prisma/client';

export class DogPostCaptionDto {
  @ApiProperty()
  id!: string;

  @ApiProperty({ example: 'Cicatriz da aventura de 2024' })
  text!: string;

  @ApiProperty({
    minimum: 0,
    maximum: 1,
    example: 0.7,
    description: 'Marker anchor as a fraction of the image width (0..1)',
  })
  x!: number;

  @ApiProperty({
    minimum: 0,
    maximum: 1,
    example: 0.3,
    description: 'Marker anchor as a fraction of the image height (0..1)',
  })
  y!: number;
}

export class DogPostImageDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  url!: string;

  @ApiProperty()
  position!: number;

  @ApiProperty({ type: [DogPostCaptionDto] })
  captions!: DogPostCaptionDto[];
}

export class DogPostDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  dogId!: string;

  @ApiProperty({ enum: DogPostType })
  type!: DogPostType;

  @ApiProperty({
    nullable: true,
    type: String,
    description:
      'Raw text with Telegram-like light markup (**bold**, __italic__, ~~strike~~, `mono`)',
  })
  text!: string | null;

  @ApiProperty({ type: [DogPostImageDto] })
  images!: DogPostImageDto[];

  @ApiProperty({ format: 'date-time' })
  createdAt!: string;

  @ApiProperty({ format: 'date-time' })
  updatedAt!: string;
}
