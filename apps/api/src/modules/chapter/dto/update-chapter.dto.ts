import {
  ArrayUnique,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class UpdateChapterDto {
  @IsOptional()
  @IsString()
  @MaxLength(256, { message: '章节标题必须在256个字符以内!' })
  title?: string;

  @IsOptional()
  @IsString()
  outline?: string;

  @IsOptional()
  @IsString()
  content?: string;

  @IsOptional()
  @IsString()
  summary?: string;

  @IsOptional()
  @IsString()
  goal?: string;

  @IsOptional()
  @IsString()
  extraNotes?: string;

  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsInt({ each: true })
  appearingCharacterIds?: number[];
}
