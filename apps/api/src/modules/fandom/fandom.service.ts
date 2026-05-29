import { Injectable, NotFoundException } from '@nestjs/common';
import { CreateFandomDto } from './dto/create-fandom.dto';
import { PrismaService } from '../prisma/prisma.service';
import { FandomModel } from 'generated/prisma/models';

@Injectable()
export class FandomService {
  constructor(private readonly prismaService: PrismaService) {}
  async create(
    userId: number,
    createFandomDto: CreateFandomDto,
  ): Promise<FandomModel> {
    const fandom = await this.prismaService.fandom.create({
      data: {
        ...createFandomDto,
        userId,
      },
    });
    return fandom;
  }

  list(userId: number): Promise<FandomModel[]> {
    return this.prismaService.fandom.findMany({
      where: {
        userId,
        deletedFlag: false,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getById(userId: number, id: number): Promise<FandomModel> {
    const fandom = await this.prismaService.fandom.findFirst({
      where: {
        id,
        userId,
        deletedFlag: false,
      },
    });
    if (!fandom) {
      throw new NotFoundException('当前 fandom 不存在！');
    }
    return fandom;
  }
}
