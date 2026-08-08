import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { DogDto } from '../../dogs/dto/dog.dto';

export class UserDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  email!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty({ nullable: true, type: String })
  phone!: string | null;

  @ApiProperty({ nullable: true, type: String })
  bio!: string | null;

  @ApiProperty({ nullable: true, type: String })
  avatarUrl!: string | null;

  @ApiProperty({ nullable: true, type: String })
  city!: string | null;

  @ApiProperty({ nullable: true, type: Number })
  latitude!: number | null;

  @ApiProperty({ nullable: true, type: Number })
  longitude!: number | null;

  @ApiProperty({ format: 'date-time' })
  createdAt!: string;

  @ApiPropertyOptional({ type: [DogDto] })
  dogs?: DogDto[];
}
