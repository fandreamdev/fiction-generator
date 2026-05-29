import {
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { NovelFanficType, NovelType } from 'generated/prisma/enums';

export class CreateNovelDto {
  @IsString()
  @IsNotEmpty({ message: '小说标题不能为空!' })
  @MaxLength(128, { message: '小说标题必须在128个字符以内!' })
  title!: string;

  @IsOptional()
  @IsNumber()
  fandomId?: number;

  @IsEnum(NovelType)
  type: NovelType = NovelType.FANFIC;

  @IsOptional()
  @IsEnum(NovelFanficType)
  fanficType?: NovelFanficType;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  divergencePoint?: string;

  @IsOptional()
  @IsString()
  tone?: string;
}
