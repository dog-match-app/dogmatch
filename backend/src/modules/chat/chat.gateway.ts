import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OnEvent } from '@nestjs/event-emitter';
import { JwtService } from '@nestjs/jwt';
import { SkipThrottle } from '@nestjs/throttler';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import {
  MATCH_CREATED_EVENT,
  MESSAGE_CREATED_EVENT,
} from '../../common/events/app-events';
import type {
  MatchCreatedEvent,
  MessageCreatedEvent,
} from '../../common/events/app-events';
import { AccessTokenPayload } from '../auth/jwt-payload.interface';
import { MessageDto } from '../matches/dto/message.dto';
import { MatchesService } from '../matches/matches.service';

interface MatchJoinPayload {
  matchId: string;
}

interface MessageSendPayload {
  matchId: string;
  content: string;
}

@SkipThrottle()
@WebSocketGateway({
  namespace: '/chat',
  cors: { origin: true, credentials: true },
})
export class ChatGateway implements OnGatewayConnection {
  private readonly logger = new Logger(ChatGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly matchesService: MatchesService,
  ) {}

  async handleConnection(client: Socket): Promise<void> {
    const token = (client.handshake.auth as Record<string, unknown>)?.token;
    if (typeof token !== 'string' || token.length === 0) {
      client.disconnect();
      return;
    }
    try {
      const payload = await this.jwtService.verifyAsync<AccessTokenPayload>(
        token,
        { secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET') },
      );
      (client.data as Record<string, unknown>).userId = payload.sub;
      await client.join(`user:${payload.sub}`);
    } catch {
      client.disconnect();
    }
  }

  @SubscribeMessage('match:join')
  async onMatchJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: MatchJoinPayload,
  ): Promise<{ joined: boolean }> {
    const userId = this.userIdOf(client);
    if (!userId || !body?.matchId) {
      return { joined: false };
    }
    try {
      const isParticipant = await this.matchesService.isParticipant(
        userId,
        body.matchId,
      );
      if (!isParticipant) {
        return { joined: false };
      }
      await client.join(`match:${body.matchId}`);
      return { joined: true };
    } catch {
      return { joined: false };
    }
  }

  @SubscribeMessage('message:send')
  async onMessageSend(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: MessageSendPayload,
  ): Promise<{ ok: boolean; message?: MessageDto }> {
    const userId = this.userIdOf(client);
    if (!userId || !body?.matchId) {
      return { ok: false };
    }
    try {
      // Broadcast happens through the shared `message.created` event handler.
      const message = await this.matchesService.createMessage(
        userId,
        body.matchId,
        body.content,
      );
      return { ok: true, message };
    } catch {
      return { ok: false };
    }
  }

  @SubscribeMessage('typing')
  onTyping(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: MatchJoinPayload,
  ): void {
    const userId = this.userIdOf(client);
    if (!userId || !body?.matchId) {
      return;
    }
    client
      .to(`match:${body.matchId}`)
      .emit('typing', { matchId: body.matchId, userId });
  }

  @OnEvent(MATCH_CREATED_EVENT)
  onMatchCreated(event: MatchCreatedEvent): void {
    for (const recipient of event.recipients) {
      this.server
        .to(`user:${recipient.userId}`)
        .emit('match:new', recipient.match);
    }
    this.logger.debug(`match:new emitted for match ${event.matchId}`);
  }

  @OnEvent(MESSAGE_CREATED_EVENT)
  onMessageCreated(event: MessageCreatedEvent): void {
    this.server
      .to(`match:${event.matchId}`)
      .to(`user:${event.recipientUserId}`)
      .emit('message:new', event.message);
  }

  private userIdOf(client: Socket): string | undefined {
    const userId = (client.data as Record<string, unknown>).userId;
    return typeof userId === 'string' ? userId : undefined;
  }
}
