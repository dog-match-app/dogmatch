import { ApiProperty } from '@nestjs/swagger';
import { DogIntent, DogSex, DogSize } from '@prisma/client';

export class DogPhotoDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  url!: string;

  @ApiProperty()
  position!: number;
}

export class DogSocialDto {
  @ApiProperty({ nullable: true, type: String, example: '+55 11 91234-0002' })
  whatsapp!: string | null;

  @ApiProperty({ nullable: true, type: String, example: '@rex.bulldog' })
  instagram!: string | null;

  @ApiProperty({ nullable: true, type: String, example: 'rexbulldog' })
  pinterest!: string | null;

  @ApiProperty({ nullable: true, type: String, example: '@rexbulldog' })
  telegram!: string | null;
}

export class DogDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  ownerId!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty()
  breed!: string;

  @ApiProperty({ enum: DogSex })
  sex!: DogSex;

  @ApiProperty({ format: 'date-time' })
  birthDate!: string;

  @ApiProperty({ enum: DogSize })
  size!: DogSize;

  @ApiProperty({ enum: DogIntent })
  intent!: DogIntent;

  @ApiProperty({ nullable: true, type: String })
  bio!: string | null;

  @ApiProperty()
  neutered!: boolean;

  @ApiProperty()
  pedigree!: boolean;

  @ApiProperty()
  active!: boolean;

  @ApiProperty({ type: [DogPhotoDto] })
  photos!: DogPhotoDto[];

  @ApiProperty({ type: DogSocialDto })
  social!: DogSocialDto;

  @ApiProperty({ format: 'date-time' })
  createdAt!: string;
}
