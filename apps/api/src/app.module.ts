import {
  MiddlewareConsumer,
  Module,
  NestModule,
  RequestMethod,
} from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { DemoUserMiddleware } from './common/demo-user.middleware';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { PrismaModule } from './modules/prisma/prisma.module';
import { QueueModule } from './modules/import/queue.module';
import appConfig from './config/app';
import { BullModule } from '@nestjs/bullmq';
import { ConfigType } from './config/configuration';
import { BullMqType } from './config/bullmq';
import { HealthController } from './health.controller';
import { FandomModule } from './modules/fandom/fandom.module';
import { NovelModule } from './modules/novel/novel.module';
import { ChapterModule } from './modules/chapter/chapter.module';

@Module({
  imports: [
    ConfigModule.forRoot({ load: [appConfig], skipProcessEnv: true }),
    PrismaModule,
    BullModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService<ConfigType>) => ({
        connection: {
          host: configService.get<BullMqType>('bullmq')?.host ?? 'localhost',
          port: configService.get<BullMqType>('bullmq')?.port ?? 6379,
        },
      }),
      inject: [ConfigService],
    }),
    QueueModule,
    FandomModule,
    NovelModule,
    ChapterModule,
  ],
  controllers: [AppController, HealthController],
  providers: [AppService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(DemoUserMiddleware)
      .forRoutes({ path: 'api/*splat', method: RequestMethod.ALL });
  }
}
