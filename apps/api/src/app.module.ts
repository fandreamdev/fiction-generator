import {
  MiddlewareConsumer,
  Module,
  NestModule,
  RequestMethod,
} from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { DemoUserMiddleware } from './common/demo-user.middleware';
import { ConfigModule } from '@nestjs/config';
import appConfig from './config/app';

@Module({
  imports: [ConfigModule.forRoot({ load: [appConfig], skipProcessEnv: true })],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(DemoUserMiddleware)
      .forRoutes({ path: 'api/*splat', method: RequestMethod.ALL });
  }
}
