import { User } from '@prisma/client';
import { DogWithPhotos, toDogDto } from '../dogs/dog.mapper';
import { UserDto } from './dto/user.dto';

export function toUserDto(user: User & { dogs?: DogWithPhotos[] }): UserDto {
  const dto: UserDto = {
    id: user.id,
    email: user.email,
    name: user.name,
    phone: user.phone,
    bio: user.bio,
    avatarUrl: user.avatarUrl,
    city: user.city,
    latitude: user.latitude,
    longitude: user.longitude,
    createdAt: user.createdAt.toISOString(),
  };
  if (user.dogs) {
    dto.dogs = user.dogs.map(toDogDto);
  }
  return dto;
}
