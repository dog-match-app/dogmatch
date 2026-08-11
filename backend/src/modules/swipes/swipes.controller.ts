import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthUser } from '../../common/decorators/current-user.decorator';
import { CreateSwipeDto } from './dto/create-swipe.dto';
import { LikesReceivedQueryDto } from './dto/likes-received-query.dto';
import { LikesReceivedDto } from './dto/likes-received.dto';
import { SwipeResultDto } from './dto/swipe-result.dto';
import { SwipesService } from './swipes.service';

@ApiTags('swipes')
@ApiBearerAuth()
@Controller('swipes')
export class SwipesController {
  constructor(private readonly swipesService: SwipesService) {}

  @Post()
  @ApiCreatedResponse({ type: SwipeResultDto })
  swipe(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateSwipeDto,
  ): Promise<SwipeResultDto> {
    return this.swipesService.swipe(user.id, dto);
  }

  @Get('received')
  @ApiOkResponse({ type: LikesReceivedDto })
  likesReceived(
    @CurrentUser() user: AuthUser,
    @Query() query: LikesReceivedQueryDto,
  ): Promise<LikesReceivedDto> {
    return this.swipesService.likesReceived(user.id, query.dogId);
  }
}
