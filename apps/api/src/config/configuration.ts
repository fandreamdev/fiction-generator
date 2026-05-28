import { AppConfig } from './app';
import { BullMqType } from './bullmq';

export type ConfigType = {
  app: AppConfig;
  bullmq: BullMqType;
};
