import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { SwipeAction } from '@prisma/client';
import { DogDto } from '../../dogs/dto/dog.dto';
import { DiscoveryOwnerDto } from './discovery-card.dto';

export class SearchCardDto {
  @ApiProperty({ type: DogDto })
  dog!: DogDto;

  @ApiProperty({
    nullable: true,
    type: Number,
    description:
      'Distance in km (1 decimal); null when either side has no location',
  })
  distanceKm!: number | null;

  @ApiProperty({ type: DiscoveryOwnerDto })
  owner!: DiscoveryOwnerDto;

  @ApiPropertyOptional({
    enum: SwipeAction,
    nullable: true,
    description:
      'Swipe already given by dogId on this dog (present only when dogId is sent)',
  })
  myAction?: SwipeAction | null;

  @ApiPropertyOptional({
    description:
      'Whether dogId and this dog already matched (present only when dogId is sent)',
  })
  matched?: boolean;
}

export class SearchResultDto {
  @ApiProperty({ type: [SearchCardDto] })
  items!: SearchCardDto[];

  @ApiProperty({ description: 'Total results across all pages' })
  total!: number;

  @ApiProperty({ description: 'Current page (1-based)' })
  page!: number;

  @ApiProperty({ description: 'Total number of pages' })
  pageCount!: number;
}
