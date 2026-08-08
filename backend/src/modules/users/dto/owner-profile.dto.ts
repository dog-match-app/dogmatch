import { ApiProperty } from '@nestjs/swagger';
import { DogDto } from '../../dogs/dto/dog.dto';

export class OwnerProfileStatsDto {
  @ApiProperty({ description: 'Number of active dogs owned by this user' })
  dogs!: number;

  @ApiProperty({ description: 'Number of matches involving any of their dogs' })
  matches!: number;
}

/**
 * Public profile of a dog owner. Privacy: never exposes email, phone,
 * coordinates (latitude/longitude) or any credential hashes.
 */
export class OwnerProfileDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty({ nullable: true, type: String })
  bio!: string | null;

  @ApiProperty({ nullable: true, type: String })
  avatarUrl!: string | null;

  @ApiProperty({ nullable: true, type: String })
  city!: string | null;

  @ApiProperty({ format: 'date-time' })
  memberSince!: string;

  @ApiProperty({
    nullable: true,
    type: Number,
    description:
      'Distance in km (1 decimal) between requester and owner; null when ' +
      'either side has no location or the profile is the requester own',
  })
  distanceKm!: number | null;

  @ApiProperty({ type: OwnerProfileStatsDto })
  stats!: OwnerProfileStatsDto;

  @ApiProperty({ type: [DogDto], description: 'Active dogs, newest first' })
  dogs!: DogDto[];
}
