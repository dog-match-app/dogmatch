import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { PresignedUploadRequestDto } from './dto/presigned-upload-request.dto';
import { PresignedUploadDto } from './dto/presigned-upload.dto';
import { FilesService } from './files.service';

@ApiTags('files')
@ApiBearerAuth()
@Controller('files')
export class FilesController {
  constructor(private readonly filesService: FilesService) {}

  @Post('presigned-upload')
  @HttpCode(HttpStatus.OK)
  @ApiOkResponse({ type: PresignedUploadDto })
  createPresignedUpload(
    @Body() dto: PresignedUploadRequestDto,
  ): Promise<PresignedUploadDto> {
    return this.filesService.createPresignedUpload(dto);
  }
}
