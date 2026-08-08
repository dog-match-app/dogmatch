import { ApiProperty } from '@nestjs/swagger';
import { DogDto } from './dog.dto';

export class DogOwnerDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty({ nullable: true, type: String })
  city!: string | null;

  @ApiProperty({ nullable: true, type: String })
  avatarUrl!: string | null;
}

export class DogDetailDto extends DogDto {
  @ApiProperty({ type: DogOwnerDto })
  owner!: DogOwnerDto;
}
