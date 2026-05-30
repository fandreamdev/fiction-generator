import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Req,
} from '@nestjs/common';
import type { Request } from 'express';
import { ChapterService } from './chapter.service';
import { CreateChapterDto } from './dto/create-chapter.dto';
import { UpdateChapterDto } from './dto/update-chapter.dto';

@Controller()
export class ChapterController {
  constructor(private readonly chapterService: ChapterService) {}

  @Post('novels/:novelId/chapters')
  create(
    @Param('novelId', ParseIntPipe) novelId: number,
    @Body() createChapterDto: CreateChapterDto,
    @Req() req: Request,
  ) {
    return this.chapterService.create(req.userId, novelId, createChapterDto);
  }

  @Get('novels/:novelId/chapters')
  findAll(
    @Param('novelId', ParseIntPipe) novelId: number,
    @Req() req: Request,
  ) {
    return this.chapterService.listByNovel(req.userId, novelId);
  }

  @Get('chapters/:id')
  findOne(@Param('id', ParseIntPipe) id: number, @Req() req: Request) {
    return this.chapterService.getById(req.userId, id);
  }

  @Put('chapters/:id')
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updateChapterDto: UpdateChapterDto,
    @Req() req: Request,
  ) {
    return this.chapterService.update(req.userId, id, updateChapterDto);
  }
}
