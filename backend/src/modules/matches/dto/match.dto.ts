import { ApiProperty } from '@nestjs/swagger';
import { DogDto } from '../../dogs/dto/dog.dto';
import { MessageDto } from './message.dto';

export class MatchOwnerDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty({ nullable: true, type: String })
  avatarUrl!: string | null;
}

export class MatchDto {
  @ApiProperty()
  id!: string;

  @ApiProperty({ format: 'date-time' })
  createdAt!: string;

  @ApiProperty({ type: DogDto })
  myDog!: DogDto;

  @ApiProperty({ type: DogDto })
  otherDog!: DogDto;

  @ApiProperty({ type: MatchOwnerDto })
  otherOwner!: MatchOwnerDto;

  @ApiProperty({ nullable: true, type: MessageDto })
  lastMessage!: MessageDto | null;
}
