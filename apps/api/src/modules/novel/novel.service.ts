import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CreateNovelDto } from './dto/create-novel.dto';
import { PrismaService } from '../prisma/prisma.service';
import { NovelStatus, NovelType } from 'generated/prisma/enums';
import { NovelModel } from 'generated/prisma/models';

@Injectable()
export class NovelService {
  constructor(private readonly prismaService: PrismaService) {}

  async create(
    userId: number,
    createNovelDto: CreateNovelDto,
  ): Promise<NovelModel> {
    return this.prismaService.$transaction(async (tx) => {
      if (NovelType.FANFIC === createNovelDto.type) {
        if (!createNovelDto.fandomId) {
          throw new BadRequestException('同人小说必须指定 fandomId');
        }
        if (!createNovelDto.fanficType) {
          throw new BadRequestException(
            '当前小说为同人小说时， 同人类型不能为空',
          );
        }
        const count = await tx.fandom.count({
          where: {
            userId,
            id: createNovelDto.fandomId,
            deletedFlag: false,
          },
        });
        if (count < 1) {
          throw new NotFoundException('当前小说关联 原作知识库 不存在');
        }
      }

      const novel = await tx.novel.create({
        data: {
          ...createNovelDto,
          userId,
          status: NovelStatus.WRITING,
          volumes: {
            create: {
              title: '正文卷',
              orderIndex: 0,
            },
          },
          writingStyles: {
            create: {
              name: '默认风格',
              user: { connect: { id: userId } },
            },
          },
        },
      });
      return novel;
    });
  }

  list(userId: number): Promise<NovelModel[]> {
    return this.prismaService.novel.findMany({
      where: { userId, deletedFlag: false },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getById(userId: number, id: number): Promise<NovelModel> {
    const novel = await this.prismaService.novel.findFirst({
      where: {
        id,
        userId,
        deletedFlag: false,
      },
      include: {
        volumes: { orderBy: { orderIndex: 'asc' } },
        writingStyles: true,
      },
    });

    if (!novel) {
      throw new NotFoundException('当前小说不存在！');
    }
    return novel;
  }
}
