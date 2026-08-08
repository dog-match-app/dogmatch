import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MessageDto } from './message.dto';

export class MessagesPageDto {
  @ApiProperty({ type: [MessageDto] })
  items!: MessageDto[];

  @ApiPropertyOptional({
    description: 'Cursor for the next (older) page, when available',
  })
  nextCursor?: string;
}
