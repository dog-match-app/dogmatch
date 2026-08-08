import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

export class MatchesQueryDto {
  @ApiProperty({ description: 'Dog whose matches should be listed' })
  @IsUUID()
  dogId!: string;
}
