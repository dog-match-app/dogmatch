import { ApiProperty } from '@nestjs/swagger';
import { UserDto } from '../../users/dto/user.dto';

export class AuthResponseDto {
  @ApiProperty({ type: UserDto })
  user!: UserDto;

  @ApiProperty()
  accessToken!: string;

  @ApiProperty()
  refreshToken!: string;
}
