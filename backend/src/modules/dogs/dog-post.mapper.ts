import { DogPost, DogPostImage, DogPostImageCaption } from '@prisma/client';
import { DogPostDto } from './dto/dog-post.dto';

export type DogPostImageWithCaptions = DogPostImage & {
  captions: DogPostImageCaption[];
};

export type DogPostWithImages = DogPost & {
  images: DogPostImageWithCaptions[];
};

export const dogPostInclude = {
  images: {
    orderBy: { position: 'asc' as const },
    include: { captions: true },
  },
};

export function toDogPostDto(post: DogPostWithImages): DogPostDto {
  return {
    id: post.id,
    dogId: post.dogId,
    type: post.type,
    text: post.text,
    images: [...post.images]
      .sort((a, b) => a.position - b.position)
      .map((image) => ({
        id: image.id,
        url: image.url,
        position: image.position,
        captions: image.captions.map((caption) => ({
          id: caption.id,
          text: caption.text,
          x: caption.x,
          y: caption.y,
        })),
      })),
    createdAt: post.createdAt.toISOString(),
    updatedAt: post.updatedAt.toISOString(),
  };
}
