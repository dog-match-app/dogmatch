import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NOTIFICATIONS_QUEUE } from './notifications.constants';
import { NotificationsListener } from './notifications.listener';
import { NotificationsProcessor } from './notifications.processor';

@Module({
  imports: [
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const url = new URL(config.getOrThrow<string>('REDIS_URL'));
        return {
          connection: {
            host: url.hostname,
            port: Number(url.port || 6379),
            ...(url.username ? { username: url.username } : {}),
            ...(url.password ? { password: url.password } : {}),
          },
        };
      },
    }),
    BullModule.registerQueue({ name: NOTIFICATIONS_QUEUE }),
  ],
  providers: [NotificationsListener, NotificationsProcessor],
})
export class NotificationsModule {}
