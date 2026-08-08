import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: 'ana@demo.com' })
  @IsEmail()
  email!: string;

  @ApiProperty({ example: 'Senha123!' })
  @IsString()
  @IsNotEmpty()
  password!: string;
}
