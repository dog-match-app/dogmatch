import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { DogIntent, DogSex, DogSize } from '@prisma/client';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateDogDto {
  @ApiProperty({ example: 'Thor' })
  @IsString()
  @MinLength(1)
  @MaxLength(60)
  name!: string;

  @ApiProperty({ example: 'Golden Retriever' })
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  breed!: string;

  @ApiProperty({ enum: DogSex })
  @IsEnum(DogSex)
  sex!: DogSex;

  @ApiProperty({ format: 'date-time', example: '2021-03-10T00:00:00.000Z' })
  @IsDateString()
  birthDate!: string;

  @ApiProperty({ enum: DogSize })
  @IsEnum(DogSize)
  size!: DogSize;

  @ApiProperty({ enum: DogIntent })
  @IsEnum(DogIntent)
  intent!: DogIntent;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  neutered?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  pedigree?: boolean;
}
