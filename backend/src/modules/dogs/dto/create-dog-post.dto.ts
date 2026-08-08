import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { DogPostType } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class CreateDogPostCaptionDto {
  @ApiProperty({
    minLength: 1,
    maxLength: 200,
    example: 'Cicatriz da aventura de 2024',
  })
  @IsString()
  @Length(1, 200)
  text!: string;

  @ApiProperty({
    minimum: 0,
    maximum: 1,
    example: 0.7,
    description: 'Marker anchor as a fraction of the image width (0..1)',
  })
  @IsNumber()
  @Min(0)
  @Max(1)
  x!: number;

  @ApiProperty({
    minimum: 0,
    maximum: 1,
    example: 0.3,
    description: 'Marker anchor as a fraction of the image height (0..1)',
  })
  @IsNumber()
  @Min(0)
  @Max(1)
  y!: number;
}

export class CreateDogPostImageDto {
  @ApiProperty({
    example: 'dogs/1f8b0c1e-uuid.jpg',
    description: 'Storage key returned by the presigned upload flow',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  key!: string;

  @ApiPropertyOptional({ minimum: 0 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  position?: number;

  @ApiPropertyOptional({
    type: [CreateDogPostCaptionDto],
    description: 'Up to 5 positioned captions',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  @ValidateNested({ each: true })
  @Type(() => CreateDogPostCaptionDto)
  captions?: CreateDogPostCaptionDto[];
}

export class CreateDogPostDto {
  @ApiProperty({ enum: DogPostType })
  @IsEnum(DogPostType)
  type!: DogPostType;

  @ApiPropertyOptional({
    minLength: 1,
    maxLength: 2000,
    description:
      'Required for TEXT and IMAGE_TEXT, forbidden for IMAGE, optional for ' +
      'CAROUSEL. Stored raw with Telegram-like light markup ' +
      '(**bold**, __italic__, ~~strike~~, `mono`)',
    example: '**Rex** adora __parques__ e ~~gatos~~ petiscos',
  })
  @IsOptional()
  @IsString()
  @Length(1, 2000)
  text?: string;

  @ApiPropertyOptional({
    type: [CreateDogPostImageDto],
    description:
      'Forbidden for TEXT, exactly 1 for IMAGE and IMAGE_TEXT, 2..8 for CAROUSEL',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(8)
  @ValidateNested({ each: true })
  @Type(() => CreateDogPostImageDto)
  images?: CreateDogPostImageDto[];
}
