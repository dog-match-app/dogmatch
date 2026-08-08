import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { DogIntent, DogSex, DogSize } from '@prisma/client';
import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

/** Trims the value; an empty (or blank) string becomes null (clears the field). */
const trimToNull = ({ value }: { value: unknown }): unknown => {
  if (typeof value !== 'string') {
    return value;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

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

  @ApiPropertyOptional({
    maxLength: 100,
    nullable: true,
    example: '+55 11 91234-0002',
    description:
      'WhatsApp handle, number or URL (free text; empty string clears it)',
  })
  @Transform(trimToNull)
  @IsOptional()
  @IsString()
  @MaxLength(100)
  whatsapp?: string | null;

  @ApiPropertyOptional({
    maxLength: 100,
    nullable: true,
    example: '@rex.bulldog',
    description: 'Instagram handle or URL (free text; empty string clears it)',
  })
  @Transform(trimToNull)
  @IsOptional()
  @IsString()
  @MaxLength(100)
  instagram?: string | null;

  @ApiPropertyOptional({
    maxLength: 100,
    nullable: true,
    example: 'rexbulldog',
    description: 'Pinterest handle or URL (free text; empty string clears it)',
  })
  @Transform(trimToNull)
  @IsOptional()
  @IsString()
  @MaxLength(100)
  pinterest?: string | null;

  @ApiPropertyOptional({
    maxLength: 100,
    nullable: true,
    example: '@rexbulldog',
    description: 'Telegram handle or URL (free text; empty string clears it)',
  })
  @Transform(trimToNull)
  @IsOptional()
  @IsString()
  @MaxLength(100)
  telegram?: string | null;
}
