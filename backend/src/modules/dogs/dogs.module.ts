import { Module } from '@nestjs/common';
import { DogPostsController } from './dog-posts.controller';
import { DogPostsService } from './dog-posts.service';
import { DogsController } from './dogs.controller';
import { DogsService } from './dogs.service';

@Module({
  controllers: [DogsController, DogPostsController],
  providers: [DogsService, DogPostsService],
})
export class DogsModule {}
