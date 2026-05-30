import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import {
  EMBEDDING_QUEUE,
  GENERATE_QUEUE,
  IMPORT_QUEUE,
} from './queue.constants';
@Module({
  imports: [
    BullModule.registerQueue(
      { name: IMPORT_QUEUE },
      { name: EMBEDDING_QUEUE },
      { name: GENERATE_QUEUE },
    ),
  ],
  exports: [BullModule],
})
export class QueueModule {}
