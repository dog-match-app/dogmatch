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
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { DogPhoto } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthUser } from '../../common/decorators/current-user.decorator';
import { DogsService } from './dogs.service';
import { AddDogPhotoDto } from './dto/add-dog-photo.dto';
import { CreateDogDto } from './dto/create-dog.dto';
import { DogDetailDto } from './dto/dog-detail.dto';
import { DogDto } from './dto/dog.dto';
import { UpdateDogDto } from './dto/update-dog.dto';

@ApiTags('dogs')
@ApiBearerAuth()
@Controller('dogs')
export class DogsController {
  constructor(private readonly dogsService: DogsService) {}

  @Get('mine')
  @ApiOkResponse({ type: [DogDto] })
  findMine(@CurrentUser() user: AuthUser): Promise<DogDto[]> {
    return this.dogsService.findMine(user.id);
  }

  @Post()
  @ApiCreatedResponse({ type: DogDto })
  create(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateDogDto,
  ): Promise<DogDto> {
    return this.dogsService.create(user.id, dto);
  }

  @Get(':id')
  @ApiOkResponse({ type: DogDetailDto })
  findOne(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<DogDetailDto> {
    return this.dogsService.findOne(user.id, id);
  }

  @Patch(':id')
  @ApiOkResponse({ type: DogDto })
  update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateDogDto,
  ): Promise<DogDto> {
    return this.dogsService.update(user.id, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<void> {
    return this.dogsService.remove(user.id, id);
  }

  @Post(':id/photos')
  addPhoto(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AddDogPhotoDto,
  ): Promise<DogPhoto> {
    return this.dogsService.addPhoto(user.id, id, dto);
  }

  @Delete(':id/photos/:photoId')
  @HttpCode(HttpStatus.NO_CONTENT)
  removePhoto(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('photoId', ParseUUIDPipe) photoId: string,
  ): Promise<void> {
    return this.dogsService.removePhoto(user.id, id, photoId);
  }
}
