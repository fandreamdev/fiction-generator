import { ConfigType, registerAs } from '@nestjs/config';

const bullmqConfig = registerAs('bullmq', () => ({
  host: process.env.BULL_MQ_HOST,
  port: parseInt(process.env.BULL_MQ_PORT ?? '6379', 10),
}));

export type BullMqType = ConfigType<typeof bullmqConfig>;
export default bullmqConfig;
