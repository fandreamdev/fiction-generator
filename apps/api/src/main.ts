import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ConfigType } from './config/configuration';
import { AppConfig } from './config/app';
import { HttpErrorFilter } from './common/http-error.filter';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.enableCors('http://localhost:5173');
  app.useGlobalFilters(new HttpErrorFilter());

  const configService = app.get(ConfigService<ConfigType>);
  const appConfig = configService.get<AppConfig>('app');
  console.log(appConfig);

  const config = new DocumentBuilder()
    .setTitle('API Docs')
    .setDescription('NestJS API documentation')
    .setVersion('1.0')
    .addTag('demo')
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document);

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
