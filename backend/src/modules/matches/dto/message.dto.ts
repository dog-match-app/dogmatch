import { ApiProperty } from '@nestjs/swagger';

export class MessageDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  matchId!: string;

  @ApiProperty()
  senderId!: string;

  @ApiProperty()
  content!: string;

  @ApiProperty({ format: 'date-time' })
  createdAt!: string;

  @ApiProperty({ nullable: true, type: String, format: 'date-time' })
  readAt!: string | null;
}
