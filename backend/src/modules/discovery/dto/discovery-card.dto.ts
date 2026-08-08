import { ApiProperty } from '@nestjs/swagger';
import { DogDto } from '../../dogs/dto/dog.dto';

export class DiscoveryOwnerDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty({ nullable: true, type: String })
  city!: string | null;

  @ApiProperty({ nullable: true, type: String })
  avatarUrl!: string | null;
}

export class DiscoveryCardDto {
  @ApiProperty({ type: DogDto })
  dog!: DogDto;

  @ApiProperty({ description: 'Distance from the owner, in km (1 decimal)' })
  distanceKm!: number;

  @ApiProperty({ type: DiscoveryOwnerDto })
  owner!: DiscoveryOwnerDto;
}
