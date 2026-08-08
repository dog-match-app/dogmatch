import { Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthUser } from '../../common/decorators/current-user.decorator';
import { DiscoveryService } from './discovery.service';
import { DiscoveryCardDto } from './dto/discovery-card.dto';
import { DiscoveryQueryDto } from './dto/discovery-query.dto';
import { SearchDogsQueryDto } from './dto/search-dogs-query.dto';
import { SearchResultDto } from './dto/search-result.dto';

@ApiTags('discovery')
@ApiBearerAuth()
@Controller('discovery')
export class DiscoveryController {
  constructor(private readonly discoveryService: DiscoveryService) {}

  @Get()
  @ApiOkResponse({ type: [DiscoveryCardDto] })
  discover(
    @CurrentUser() user: AuthUser,
    @Query() query: DiscoveryQueryDto,
  ): Promise<DiscoveryCardDto[]> {
    return this.discoveryService.discover(user.id, query);
  }

  @Get('search')
  @ApiOkResponse({ type: SearchResultDto })
  search(
    @CurrentUser() user: AuthUser,
    @Query() query: SearchDogsQueryDto,
  ): Promise<SearchResultDto> {
    return this.discoveryService.search(user.id, query);
  }
}
