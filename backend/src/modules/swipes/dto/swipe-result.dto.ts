import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MatchDto } from '../../matches/dto/match.dto';

export class SwipeResultDto {
  @ApiProperty()
  matched!: boolean;

  @ApiPropertyOptional({ type: MatchDto })
  match?: MatchDto;
}
