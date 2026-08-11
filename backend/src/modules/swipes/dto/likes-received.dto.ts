import { ApiProperty } from '@nestjs/swagger';
import { SwipeAction } from '@prisma/client';
import { DiscoveryOwnerDto } from '../../discovery/dto/discovery-card.dto';
import { DogDto } from '../../dogs/dto/dog.dto';

export class LikeReceivedDto {
  @ApiProperty({ type: DogDto, description: 'Dog that gave the like' })
  dog!: DogDto;

  @ApiProperty({
    nullable: true,
    type: Number,
    description:
      'Distance between the owners in km (1 decimal); null when either owner has no location',
  })
  distanceKm!: number | null;

  @ApiProperty({ type: DiscoveryOwnerDto })
  owner!: DiscoveryOwnerDto;

  @ApiProperty({
    format: 'date-time',
    description: 'When the like was given (latest swipe createdAt)',
  })
  likedAt!: string;

  @ApiProperty({
    enum: [SwipeAction.PASS],
    nullable: true,
    description:
      "Caller's swipe on the liker dog: PASS (reversible by liking back) or null",
  })
  myAction!: 'PASS' | null;
}

export class LikesReceivedDto {
  @ApiProperty({ type: [LikeReceivedDto] })
  items!: LikeReceivedDto[];

  @ApiProperty({ description: 'Pending likes matching the same filters' })
  total!: number;
}
