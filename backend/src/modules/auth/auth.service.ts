import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import type { JwtSignOptions } from '@nestjs/jwt';
import * as argon2 from 'argon2';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { toUserDto } from '../users/user.mapper';
import { AuthResponseDto } from './dto/auth-response.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { TokensDto } from './dto/tokens.dto';
import { RefreshTokenPayload } from './jwt-payload.interface';

@Injectable()
export class AuthService {
  private readonly accessSecret: string;
  private readonly accessTtl: JwtSignOptions['expiresIn'];
  private readonly refreshSecret: string;
  private readonly refreshTtl: JwtSignOptions['expiresIn'];

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    config: ConfigService,
  ) {
    this.accessSecret = config.getOrThrow<string>('JWT_ACCESS_SECRET');
    this.accessTtl = config.getOrThrow<string>(
      'JWT_ACCESS_TTL',
    ) as JwtSignOptions['expiresIn'];
    this.refreshSecret = config.getOrThrow<string>('JWT_REFRESH_SECRET');
    this.refreshTtl = config.getOrThrow<string>(
      'JWT_REFRESH_TTL',
    ) as JwtSignOptions['expiresIn'];
  }

  async register(dto: RegisterDto): Promise<AuthResponseDto> {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (existing) {
      throw new ConflictException('Email already registered');
    }
    const passwordHash = await argon2.hash(dto.password);
    const user = await this.prisma.user.create({
      data: { email: dto.email, passwordHash, name: dto.name },
    });
    const tokens = await this.issueTokens(user.id, user.email);
    return { user: toUserDto({ ...user, dogs: [] }), ...tokens };
  }

  async login(dto: LoginDto): Promise<AuthResponseDto> {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
      include: {
        dogs: { include: { photos: { orderBy: { position: 'asc' } } } },
      },
    });
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const valid = await argon2.verify(user.passwordHash, dto.password);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const tokens = await this.issueTokens(user.id, user.email);
    return { user: toUserDto(user), ...tokens };
  }

  async refresh(refreshToken: string): Promise<TokensDto> {
    const payload = await this.verifyRefreshToken(refreshToken);
    const stored = await this.prisma.refreshToken.findUnique({
      where: { id: payload.jti },
    });
    if (!stored || stored.revokedAt || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid refresh token');
    }
    const hashMatches = await argon2
      .verify(stored.tokenHash, refreshToken)
      .catch(() => false);
    if (!hashMatches) {
      throw new UnauthorizedException('Invalid refresh token');
    }
    const user = await this.prisma.user.findUnique({
      where: { id: stored.userId },
    });
    if (!user) {
      throw new UnauthorizedException('Invalid refresh token');
    }
    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });
    return this.issueTokens(user.id, user.email);
  }

  async logout(userId: string, refreshToken: string): Promise<void> {
    const payload = await this.verifyRefreshToken(refreshToken);
    const stored = await this.prisma.refreshToken.findUnique({
      where: { id: payload.jti },
    });
    if (stored && stored.userId === userId && !stored.revokedAt) {
      await this.prisma.refreshToken.update({
        where: { id: stored.id },
        data: { revokedAt: new Date() },
      });
    }
  }

  private async verifyRefreshToken(
    refreshToken: string,
  ): Promise<RefreshTokenPayload> {
    try {
      return await this.jwtService.verifyAsync<RefreshTokenPayload>(
        refreshToken,
        { secret: this.refreshSecret },
      );
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  private async issueTokens(userId: string, email: string): Promise<TokensDto> {
    const accessToken = await this.jwtService.signAsync(
      { sub: userId, email },
      { secret: this.accessSecret, expiresIn: this.accessTtl },
    );
    const jti = randomUUID();
    const refreshToken = await this.jwtService.signAsync(
      { sub: userId, jti },
      { secret: this.refreshSecret, expiresIn: this.refreshTtl },
    );
    const decoded = this.jwtService.decode<{ exp: number }>(refreshToken);
    const tokenHash = await argon2.hash(refreshToken);
    await this.prisma.refreshToken.create({
      data: {
        id: jti,
        userId,
        tokenHash,
        expiresAt: new Date(decoded.exp * 1000),
      },
    });
    return { accessToken, refreshToken };
  }
}
