import { ApiProperty } from '@nestjs/swagger';
import { IsIn } from 'class-validator';

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
}
