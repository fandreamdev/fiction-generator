import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateChapterDto } from './dto/create-chapter.dto';
import { UpdateChapterDto } from './dto/update-chapter.dto';
import { ChapterStatus } from 'generated/prisma/enums';
import { ChapterModel } from 'generated/prisma/models';

@Injectable()
export class ChapterService {
  constructor(private readonly prismaService: PrismaService) {}

  async create(
    userId: number,
    novelId: number,
    createChapterDto: CreateChapterDto,
  ): Promise<ChapterModel> {
    return this.prismaService.$transaction(async (tx) => {
      const novel = await tx.novel.findFirst({
        where: { id: novelId, userId, deletedFlag: false },
        include: {
          volumes: {
            where: { deletedFlag: false },
            orderBy: { orderIndex: 'asc' },
            take: 1,
          },
        },
      });
      if (!novel) {
        throw new NotFoundException('当前小说不存在！');
      }
      const volume = novel.volumes[0];
      if (!volume) {
        throw new NotFoundException('当前小说缺少默认分卷！');
      }

      const last = await tx.chapter.findFirst({
        where: { novelId, deletedFlag: false },
        orderBy: { chapterNo: 'desc' },
        select: { chapterNo: true },
      });
      const chapterNo = (last?.chapterNo ?? 0) + 1;

      return tx.chapter.create({
        data: {
          novelId,
          volumeId: volume.id,
          chapterNo,
          title: createChapterDto.title ?? `第 ${chapterNo} 章`,
          outline: createChapterDto.outline,
          status: ChapterStatus.DRAFT,
          wordCount: 0,
        },
      });
    });
  }

  listByNovel(userId: number, novelId: number): Promise<ChapterModel[]> {
    return this.prismaService.chapter.findMany({
      where: {
        novelId,
        deletedFlag: false,
        novel: { userId, deletedFlag: false },
      },
      orderBy: { chapterNo: 'asc' },
    });
  }

  async getById(userId: number, id: number): Promise<ChapterModel> {
    const chapter = await this.prismaService.chapter.findFirst({
      where: {
        id,
        deletedFlag: false,
        novel: { userId, deletedFlag: false },
      },
    });
    if (!chapter) {
      throw new NotFoundException('当前章节不存在！');
    }
    return chapter;
  }

  async update(
    userId: number,
    id: number,
    updateChapterDto: UpdateChapterDto,
  ): Promise<ChapterModel> {
    await this.getById(userId, id);

    const { content } = updateChapterDto;
    return this.prismaService.chapter.update({
      where: { id },
      data: {
        ...updateChapterDto,
        ...(content !== undefined ? { wordCount: content.length } : {}),
      },
    });
  }
}
