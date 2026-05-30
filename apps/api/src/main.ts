import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ConfigType } from './config/configuration';
import { AppConfig } from './config/app';
import { HttpErrorFilter } from './common/http-error.filter';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ExpressAdapter } from '@bull-board/express';
import { createBullBoard } from '@bull-board/api';
import { BullMQAdapter } from '@bull-board/api/bullMQAdapter';

import { getQueueToken } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import {
  EMBEDDING_QUEUE,
  GENERATE_QUEUE,
  IMPORT_QUEUE,
} from './modules/import/queue.constants';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.enableCors({ origin: 'http://localhost:5173' });
  app.useGlobalFilters(new HttpErrorFilter());
  app.setGlobalPrefix('api');

  const configService = app.get(ConfigService<ConfigType>);
  const appConfig = configService.get<AppConfig>('app');
  console.log(appConfig);

  // 配置swagger
  const config = new DocumentBuilder()
    .setTitle('API Docs')
    .setDescription('NestJS API documentation')
    .setVersion('1.0')
    .addTag('demo')
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document);

  // 配置 bull board
  const serverAdapter = new ExpressAdapter();
  serverAdapter.setBasePath('/admin/queues');

  const importQueue = app.get<Queue>(getQueueToken(IMPORT_QUEUE));
  const embeddingQueue = app.get<Queue>(getQueueToken(EMBEDDING_QUEUE));
  const generateQueue = app.get<Queue>(getQueueToken(GENERATE_QUEUE));
  createBullBoard({
    queues: [
      new BullMQAdapter(importQueue),
      new BullMQAdapter(embeddingQueue),
      new BullMQAdapter(generateQueue),
    ],
    serverAdapter,
  });
  app.use('/admin/queues', serverAdapter.getRouter());

  await app.listen(process.env.PORT ?? 3000);

  console.log(`API: ${await app.getUrl()}`);
  console.log(`Swagger: ${await app.getUrl()}/docs`);
  console.log(`Bull Board: ${await app.getUrl()}/admin/queues`);
}
bootstrap();
