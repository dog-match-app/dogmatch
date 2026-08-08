import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import {
  AllowedContentType,
  PresignedUploadRequestDto,
} from './dto/presigned-upload-request.dto';
import { PresignedUploadDto } from './dto/presigned-upload.dto';

const UPLOAD_URL_TTL_SECONDS = 300;

const EXTENSION_BY_CONTENT_TYPE: Record<AllowedContentType, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

@Injectable()
export class FilesService {
  private readonly s3: S3Client;
  private readonly bucket: string;
  private readonly publicUrl: string;

  constructor(config: ConfigService) {
    this.s3 = new S3Client({
      endpoint: config.getOrThrow<string>('S3_ENDPOINT'),
      region: config.getOrThrow<string>('S3_REGION'),
      forcePathStyle: true,
      credentials: {
        accessKeyId: config.getOrThrow<string>('S3_ACCESS_KEY'),
        secretAccessKey: config.getOrThrow<string>('S3_SECRET_KEY'),
      },
    });
    this.bucket = config.getOrThrow<string>('S3_BUCKET');
    this.publicUrl = config.getOrThrow<string>('S3_PUBLIC_URL');
  }

  async createPresignedUpload(
    dto: PresignedUploadRequestDto,
  ): Promise<PresignedUploadDto> {
    const extension = EXTENSION_BY_CONTENT_TYPE[dto.contentType];
    const key = `${dto.folder}/${randomUUID()}.${extension}`;
    const uploadUrl = await getSignedUrl(
      this.s3,
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        ContentType: dto.contentType,
      }),
      { expiresIn: UPLOAD_URL_TTL_SECONDS },
    );
    return {
      uploadUrl,
      publicUrl: `${this.publicUrl}/${key}`,
      key,
      expiresIn: UPLOAD_URL_TTL_SECONDS,
    };
  }
}
