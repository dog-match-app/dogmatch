import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthUser } from '../../common/decorators/current-user.decorator';
import { CreateMessageDto } from './dto/create-message.dto';
import { MatchDto } from './dto/match.dto';
import { MatchesQueryDto } from './dto/matches-query.dto';
import { MessageDto } from './dto/message.dto';
import { MessagesPageDto } from './dto/messages-page.dto';
import { MessagesQueryDto } from './dto/messages-query.dto';
import { MatchesService } from './matches.service';

@ApiTags('matches')
@ApiBearerAuth()
@Controller('matches')
export class MatchesController {
  constructor(private readonly matchesService: MatchesService) {}

  @Get()
  @ApiOkResponse({ type: [MatchDto] })
  list(
    @CurrentUser() user: AuthUser,
    @Query() query: MatchesQueryDto,
  ): Promise<MatchDto[]> {
    return this.matchesService.list(user.id, query.dogId);
  }

  @Get(':id/messages')
  @ApiOkResponse({ type: MessagesPageDto })
  getMessages(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Query() query: MessagesQueryDto,
  ): Promise<MessagesPageDto> {
    return this.matchesService.getMessages(
      user.id,
      id,
      query.cursor,
      query.limit ?? 30,
    );
  }

  @Post(':id/messages')
  @ApiCreatedResponse({ type: MessageDto })
  createMessage(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateMessageDto,
  ): Promise<MessageDto> {
    return this.matchesService.createMessage(user.id, id, dto.content);
  }
}
