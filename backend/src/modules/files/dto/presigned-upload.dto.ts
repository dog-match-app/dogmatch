import { ApiProperty } from '@nestjs/swagger';

export class PresignedUploadDto {
  @ApiProperty()
  uploadUrl!: string;

  @ApiProperty()
  publicUrl!: string;

  @ApiProperty()
  key!: string;

  @ApiProperty({ description: 'Expiration of the upload URL, in seconds' })
  expiresIn!: number;
}
