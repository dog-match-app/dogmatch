import Joi from 'joi';

export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'test', 'production')
    .default('development'),
  PORT: Joi.number().port().default(3000),
  DATABASE_URL: Joi.string().default(
    'postgresql://dogmatch:dogmatch@localhost:5432/dogmatch?schema=public',
  ),
  JWT_ACCESS_SECRET: Joi.string().default('dev-access-secret-change-me'),
  JWT_ACCESS_TTL: Joi.string().default('15m'),
  JWT_REFRESH_SECRET: Joi.string().default('dev-refresh-secret-change-me'),
  JWT_REFRESH_TTL: Joi.string().default('30d'),
  REDIS_URL: Joi.string().default('redis://localhost:6379'),
  S3_ENDPOINT: Joi.string().default('http://localhost:9000'),
  S3_REGION: Joi.string().default('us-east-1'),
  S3_ACCESS_KEY: Joi.string().default('dogmatch'),
  S3_SECRET_KEY: Joi.string().default('dogmatch123'),
  S3_BUCKET: Joi.string().default('dogmatch-media'),
  S3_PUBLIC_URL: Joi.string().default('http://localhost:9000/dogmatch-media'),
  CORS_ORIGINS: Joi.string().default('*'),
  THROTTLE_TTL: Joi.number().default(60000),
  THROTTLE_LIMIT: Joi.number().default(100),
});
