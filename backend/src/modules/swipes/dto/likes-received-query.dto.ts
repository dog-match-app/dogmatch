import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUUID } from 'class-validator';

export class LikesReceivedQueryDto {
  @ApiPropertyOptional({
    description:
      'Dog whose received likes should be listed; omit to aggregate every active dog of the caller',
  })
  @IsOptional()
  @IsUUID()
  dogId?: string;
}
