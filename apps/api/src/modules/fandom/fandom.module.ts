import { Module } from '@nestjs/common';
import { FandomService } from './fandom.service';
import { FandomController } from './fandom.controller';

@Module({
  controllers: [FandomController],
  providers: [FandomService],
})
export class FandomModule {}
