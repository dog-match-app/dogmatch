import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthUser } from '../../common/decorators/current-user.decorator';
import { DogPostsService } from './dog-posts.service';
import { CreateDogPostDto } from './dto/create-dog-post.dto';
import { DogPostDto } from './dto/dog-post.dto';
import { UpdateDogPostDto } from './dto/update-dog-post.dto';

@ApiTags('dogs')
@ApiBearerAuth()
@Controller('dogs/:id/posts')
export class DogPostsController {
  constructor(private readonly dogPostsService: DogPostsService) {}

  @Get()
  @ApiOperation({ summary: 'Dog page posts (newest first)' })
  @ApiOkResponse({ type: [DogPostDto] })
  findAll(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) dogId: string,
  ): Promise<DogPostDto[]> {
    return this.dogPostsService.findAll(user.id, dogId);
  }

  @Post()
  @ApiOperation({
    summary: 'Create a post (owner only; up to 10 per dog)',
    description:
      'TEXT: text 1..2000, no images. IMAGE: exactly 1 image, no text. ' +
      'IMAGE_TEXT: exactly 1 image + text 1..2000. CAROUSEL: 2..8 images, ' +
      'optional text. Up to 5 positioned captions per image.',
  })
  @ApiCreatedResponse({ type: DogPostDto })
  create(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) dogId: string,
    @Body() dto: CreateDogPostDto,
  ): Promise<DogPostDto> {
    return this.dogPostsService.create(user.id, dogId, dto);
  }

  @Patch(':postId')
  @ApiOperation({
    summary:
      'Replace post content (owner only; type is immutable and must not be sent)',
  })
  @ApiOkResponse({ type: DogPostDto })
  update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) dogId: string,
    @Param('postId', ParseUUIDPipe) postId: string,
    @Body() dto: UpdateDogPostDto,
  ): Promise<DogPostDto> {
    return this.dogPostsService.update(user.id, dogId, postId, dto);
  }

  @Delete(':postId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a post (owner only)' })
  @ApiNoContentResponse()
  remove(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) dogId: string,
    @Param('postId', ParseUUIDPipe) postId: string,
  ): Promise<void> {
    return this.dogPostsService.remove(user.id, dogId, postId);
  }
}
