import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MinLength } from 'class-validator';

export class RegisterDto {
  @ApiProperty({ example: 'ana@demo.com' })
  @IsEmail()
  email!: string;

  @ApiProperty({ minLength: 8, example: 'Senha123!' })
  @IsString()
  @MinLength(8)
  password!: string;

  @ApiProperty({ minLength: 2, example: 'Ana Souza' })
  @IsString()
  @MinLength(2)
  name!: string;
}
