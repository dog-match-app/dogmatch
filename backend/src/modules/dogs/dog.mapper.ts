import { Dog, DogPhoto } from '@prisma/client';
import { DogDto } from './dto/dog.dto';

export type DogWithPhotos = Dog & { photos: DogPhoto[] };

export function toDogDto(dog: DogWithPhotos): DogDto {
  return {
    id: dog.id,
    ownerId: dog.ownerId,
    name: dog.name,
    breed: dog.breed,
    sex: dog.sex,
    birthDate: dog.birthDate.toISOString(),
    size: dog.size,
    intent: dog.intent,
    bio: dog.bio,
    neutered: dog.neutered,
    pedigree: dog.pedigree,
    active: dog.active,
    photos: [...dog.photos]
      .sort((a, b) => a.position - b.position)
      .map((photo) => ({
        id: photo.id,
        url: photo.url,
        position: photo.position,
      })),
    createdAt: dog.createdAt.toISOString(),
  };
}
