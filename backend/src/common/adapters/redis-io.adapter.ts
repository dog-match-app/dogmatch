import { Logger } from '@nestjs/common';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import Redis from 'ioredis';
import { Server, ServerOptions } from 'socket.io';

export class RedisIoAdapter extends IoAdapter {
  private readonly logger = new Logger(RedisIoAdapter.name);
  private adapterConstructor?: ReturnType<typeof createAdapter>;

  async connectToRedis(url: string): Promise<void> {
    const pubClient = new Redis(url, {
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      retryStrategy: (times: number) => (times > 3 ? null : 300),
    });
    const subClient = pubClient.duplicate();
    try {
      await Promise.all([pubClient.connect(), subClient.connect()]);
      this.adapterConstructor = createAdapter(pubClient, subClient);
      this.logger.log('Socket.IO Redis adapter enabled');
    } catch {
      pubClient.disconnect();
      subClient.disconnect();
      this.logger.warn(
        'Could not connect to Redis, falling back to the in-memory Socket.IO adapter',
      );
    }
  }

  createIOServer(port: number, options?: ServerOptions): Server {
    const server = super.createIOServer(port, options) as Server;
    if (this.adapterConstructor) {
      server.adapter(this.adapterConstructor);
    }
    return server;
  }
}
