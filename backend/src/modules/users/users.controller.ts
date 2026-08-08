import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthUser } from '../../common/decorators/current-user.decorator';
import { UpdateUserDto } from './dto/update-user.dto';
import { UserDto } from './dto/user.dto';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @ApiOkResponse({ type: UserDto })
  me(@CurrentUser() user: AuthUser): Promise<UserDto> {
    return this.usersService.me(user.id);
  }

  @Patch('me')
  @ApiOkResponse({ type: UserDto })
  updateMe(
    @CurrentUser() user: AuthUser,
    @Body() dto: UpdateUserDto,
  ): Promise<UserDto> {
    return this.usersService.updateMe(user.id, dto);
  }
}
