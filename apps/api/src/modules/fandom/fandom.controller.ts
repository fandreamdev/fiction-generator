import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  Req,
  ParseIntPipe,
} from '@nestjs/common';
import { FandomService } from './fandom.service';
import { CreateFandomDto } from './dto/create-fandom.dto';
import { UpdateFandomDto } from './dto/update-fandom.dto';
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

  @Patch(':id')
  update(@Param('id') id: string, @Body() updateFandomDto: UpdateFandomDto) {
    return this.fandomService.update(+id, updateFandomDto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.fandomService.remove(+id);
  }
}
