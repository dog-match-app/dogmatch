import { OmitType } from '@nestjs/swagger';
import { CreateDogPostDto } from './create-dog-post.dto';

/**
 * Same shape as the create body but WITHOUT `type` (a post never changes
 * type). Sending `type` is rejected with 400 by the global ValidationPipe
 * (`forbidNonWhitelisted`). The content (text/images/captions) is fully
 * replaced and revalidated against the post's ORIGINAL type.
 */
export class UpdateDogPostDto extends OmitType(CreateDogPostDto, [
  'type',
] as const) {}
