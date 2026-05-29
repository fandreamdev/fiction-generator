import { Module } from '@nestjs/common';
import { FandomService } from './fandom.service';
import { FandomController } from './fandom.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [FandomController],
  providers: [FandomService],
})
export class FandomModule {}
