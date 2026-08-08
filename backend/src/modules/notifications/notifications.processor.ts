import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { NOTIFICATIONS_QUEUE } from './notifications.constants';

@Processor(NOTIFICATIONS_QUEUE)
export class NotificationsProcessor extends WorkerHost {
  private readonly logger = new Logger(NotificationsProcessor.name);

  // Placeholder: this is where FCM push notifications will be sent in the
  // future. For now the job payload is only logged.
  async process(job: Job): Promise<void> {
    this.logger.log(
      `Notification job "${job.name}" received: ${JSON.stringify(job.data)}`,
    );
    await Promise.resolve();
  }
}
