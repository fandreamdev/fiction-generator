import { IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateChapterDto {
  @IsOptional()
  @IsString()
  @MaxLength(256, { message: '章节标题必须在256个字符以内!' })
  title?: string;

  @IsOptional()
  @IsString()
  outline?: string;
}
