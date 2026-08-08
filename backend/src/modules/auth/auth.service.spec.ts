import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import * as argon2 from 'argon2';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthService } from './auth.service';

const CONFIG_VALUES: Record<string, string> = {
  JWT_ACCESS_SECRET: 'test-access-secret',
  JWT_ACCESS_TTL: '15m',
  JWT_REFRESH_SECRET: 'test-refresh-secret',
  JWT_REFRESH_TTL: '30d',
};

describe('AuthService', () => {
  let service: AuthService;

  const prismaMock = {
    user: { findUnique: jest.fn(), create: jest.fn() },
    refreshToken: {
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
    },
  };
  const jwtMock = {
    signAsync: jest.fn(),
    verifyAsync: jest.fn(),
    decode: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    jwtMock.signAsync.mockResolvedValue('signed-token');
    jwtMock.decode.mockReturnValue({
      exp: Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60,
    });
    prismaMock.refreshToken.create.mockResolvedValue({});

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: JwtService, useValue: jwtMock },
        {
          provide: ConfigService,
          useValue: {
            getOrThrow: jest.fn((key: string) => CONFIG_VALUES[key]),
          },
        },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  describe('register', () => {
    const dto = { email: 'new@demo.com', password: 'Senha123!', name: 'New' };

    it('stores an argon2 hash of the password, never the plain text', async () => {
      prismaMock.user.findUnique.mockResolvedValue(null);
      prismaMock.user.create.mockImplementation(
        (args: {
          data: { email: string; passwordHash: string; name: string };
        }) =>
          Promise.resolve({
            id: 'user-1',
            ...args.data,
            phone: null,
            bio: null,
            avatarUrl: null,
            city: null,
            latitude: null,
            longitude: null,
            createdAt: new Date(),
            updatedAt: new Date(),
          }),
      );

      const result = await service.register(dto);

      const createArgs = (
        prismaMock.user.create.mock.calls as unknown as [
          [{ data: { passwordHash: string } }],
        ]
      )[0][0];
      expect(createArgs.data.passwordHash).not.toBe(dto.password);
      await expect(
        argon2.verify(createArgs.data.passwordHash, dto.password),
      ).resolves.toBe(true);
      expect(result.accessToken).toBe('signed-token');
      expect(result.refreshToken).toBe('signed-token');
      expect(result.user.email).toBe(dto.email);
      expect(prismaMock.refreshToken.create).toHaveBeenCalledTimes(1);
    });

    it('throws ConflictException when the email is already registered', async () => {
      prismaMock.user.findUnique.mockResolvedValue({ id: 'user-1' });

      await expect(service.register(dto)).rejects.toBeInstanceOf(
        ConflictException,
      );
      expect(prismaMock.user.create).not.toHaveBeenCalled();
    });
  });

  describe('login', () => {
    it('throws UnauthorizedException on wrong password', async () => {
      prismaMock.user.findUnique.mockResolvedValue({
        id: 'user-1',
        email: 'ana@demo.com',
        name: 'Ana',
        passwordHash: await argon2.hash('Senha123!'),
        phone: null,
        bio: null,
        avatarUrl: null,
        city: null,
        latitude: null,
        longitude: null,
        createdAt: new Date(),
        updatedAt: new Date(),
        dogs: [],
      });

      await expect(
        service.login({ email: 'ana@demo.com', password: 'WrongPass1!' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect(jwtMock.signAsync).not.toHaveBeenCalled();
    });
  });
});
