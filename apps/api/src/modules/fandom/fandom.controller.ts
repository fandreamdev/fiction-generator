import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Req,
  ParseIntPipe,
} from '@nestjs/common';
import { FandomService } from './fandom.service';
import { CreateFandomDto } from './dto/create-fandom.dto';
import type { Request } from 'express';

@Controller('fandoms')
export class FandomController {
  constructor(private readonly fandomService: FandomService) {}

  @Post()
  create(@Body() createFandomDto: CreateFandomDto, @Req() req: Request) {
    return this.fandomService.create(req.userId, createFandomDto);
  }

  @Get()
  findAll(@Req() req: Request) {
    return this.fandomService.list(req.userId);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number, @Req() req: Request) {
    return this.fandomService.getById(req.userId, id);
  }
}
