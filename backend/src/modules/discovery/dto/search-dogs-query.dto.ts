import { ApiPropertyOptional } from '@nestjs/swagger';
import { DogIntent, DogSex, DogSize } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export type SearchIntent =
  typeof DogIntent.BREEDING | typeof DogIntent.FRIENDSHIP;

export type SearchOrderBy = 'distance' | 'recent';

const trimToUndefined = ({ value }: { value: unknown }): unknown => {
  if (typeof value !== 'string') {
    return value;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
};

const csvToArray = ({ value }: { value: unknown }): unknown => {
  if (typeof value !== 'string') {
    return value;
  }
  const items = value
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
  return items.length > 0 ? items : undefined;
};

const stringToBoolean = ({ value }: { value: unknown }): unknown =>
  value === 'true' ? true : value === 'false' ? false : value;

export class SearchDogsQueryDto {
  @ApiPropertyOptional({
    description: 'Text search on name and breed (case-insensitive contains)',
    maxLength: 100,
    example: 'golden',
  })
  @IsOptional()
  @Transform(trimToUndefined)
  @IsString()
  @MaxLength(100)
  q?: string;

  @ApiPropertyOptional({ enum: DogSex })
  @IsOptional()
  @IsEnum(DogSex)
  sex?: DogSex;

  @ApiPropertyOptional({
    type: String,
    example: 'SMALL,MEDIUM',
    description: 'Comma-separated sizes (SMALL, MEDIUM, LARGE, GIANT)',
  })
  @IsOptional()
  @Transform(csvToArray)
  @IsArray()
  @IsEnum(DogSize, { each: true })
  size?: DogSize[];

  @ApiPropertyOptional({
    enum: [DogIntent.BREEDING, DogIntent.FRIENDSHIP],
    description:
      'BREEDING matches targets IN (BREEDING, BOTH); FRIENDSHIP matches targets IN (FRIENDSHIP, BOTH)',
  })
  @IsOptional()
  @IsIn([DogIntent.BREEDING, DogIntent.FRIENDSHIP])
  intent?: SearchIntent;

  @ApiPropertyOptional({
    minimum: 0,
    maximum: 30,
    description: 'Minimum age in full years (inclusive)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(30)
  ageMinYears?: number;

  @ApiPropertyOptional({
    minimum: 0,
    maximum: 30,
    description: 'Maximum age in full years (inclusive)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(30)
  ageMaxYears?: number;

  @ApiPropertyOptional({
    type: Boolean,
    description: "Filter by neutered status ('true' or 'false')",
  })
  @IsOptional()
  @Transform(stringToBoolean)
  @IsBoolean()
  neutered?: boolean;

  @ApiPropertyOptional({
    type: Boolean,
    description: "Filter by pedigree status ('true' or 'false')",
  })
  @IsOptional()
  @Transform(stringToBoolean)
  @IsBoolean()
  pedigree?: boolean;

  @ApiPropertyOptional({
    minimum: 1,
    maximum: 500,
    description:
      'Max distance in km from the logged user location (400 LOCATION_REQUIRED without lat/lng)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(500)
  radiusKm?: number;

  @ApiPropertyOptional({
    format: 'uuid',
    description:
      'Perspective dog (must belong to the user): enables myAction/matched on cards and excludeSwiped',
  })
  @IsOptional()
  @IsUUID()
  dogId?: string;

  @ApiPropertyOptional({
    type: Boolean,
    default: false,
    description: 'Hide dogs already swiped by dogId (requires dogId)',
  })
  @IsOptional()
  @Transform(stringToBoolean)
  @IsBoolean()
  excludeSwiped?: boolean = false;

  @ApiPropertyOptional({
    enum: ['distance', 'recent'],
    description:
      "Default: 'distance' when the user has a location, otherwise 'recent'",
  })
  @IsOptional()
  @IsIn(['distance', 'recent'])
  orderBy?: SearchOrderBy;

  @ApiPropertyOptional({ default: 1, minimum: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ default: 20, minimum: 1, maximum: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number = 20;
}
