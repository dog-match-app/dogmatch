import { ApiProperty } from '@nestjs/swagger';
import { SwipeAction } from '@prisma/client';
import { IsEnum, IsUUID } from 'class-validator';

export class CreateSwipeDto {
  @ApiProperty()
  @IsUUID()
  swiperDogId!: string;

  @ApiProperty()
  @IsUUID()
  targetDogId!: string;

  @ApiProperty({ enum: SwipeAction })
  @IsEnum(SwipeAction)
  action!: SwipeAction;
}
