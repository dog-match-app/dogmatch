import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class AddDogPhotoDto {
  @ApiProperty({ example: 'dogs/1f8b0c1e-uuid.jpg' })
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
}
