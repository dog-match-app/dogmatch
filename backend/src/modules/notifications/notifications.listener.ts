import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { Queue } from 'bullmq';
import { MATCH_CREATED_EVENT } from '../../common/events/app-events';
import type { MatchCreatedEvent } from '../../common/events/app-events';
import { NOTIFICATIONS_QUEUE } from './notifications.constants';

@Injectable()
export class NotificationsListener {
  private readonly logger = new Logger(NotificationsListener.name);

  constructor(
    @InjectQueue(NOTIFICATIONS_QUEUE) private readonly queue: Queue,
  ) {}

  @OnEvent(MATCH_CREATED_EVENT)
  async onMatchCreated(event: MatchCreatedEvent): Promise<void> {
    try {
      await this.queue.add('match-created', {
        matchId: event.matchId,
        userIds: event.recipients.map((recipient) => recipient.userId),
      });
    } catch (error) {
      this.logger.warn(
        `Failed to enqueue match-created notification: ${(error as Error).message}`,
      );
    }
  }
}
