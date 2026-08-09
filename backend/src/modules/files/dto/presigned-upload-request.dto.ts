import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, Max, Min } from 'class-validator';

/** Hard cap per upload; the signed URL is bound to the declared size. */
export const MAX_UPLOAD_BYTES = 20 * 1024 * 1024;

export const ALLOWED_CONTENT_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
] as const;
export type AllowedContentType = (typeof ALLOWED_CONTENT_TYPES)[number];

export const ALLOWED_FOLDERS = ['avatars', 'dogs'] as const;
export type AllowedFolder = (typeof ALLOWED_FOLDERS)[number];

export class PresignedUploadRequestDto {
  @ApiProperty({ enum: ALLOWED_CONTENT_TYPES })
  @IsIn(ALLOWED_CONTENT_TYPES)
  contentType!: AllowedContentType;

  @ApiProperty({ enum: ALLOWED_FOLDERS })
  @IsIn(ALLOWED_FOLDERS)
  folder!: AllowedFolder;

  @ApiProperty({
    minimum: 1,
    maximum: MAX_UPLOAD_BYTES,
    description:
      'Exact size in bytes of the file. The signed URL only accepts a body of this size.',
  })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(MAX_UPLOAD_BYTES)
  contentLength!: number;
}
