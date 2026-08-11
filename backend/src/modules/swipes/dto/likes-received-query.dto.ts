import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

export class LikesReceivedQueryDto {
  @ApiProperty({ description: 'Dog whose received likes should be listed' })
  @IsUUID()
  dogId!: string;
}
