import { IsString, MaxLength, IsOptional, IsEnum } from 'class-validator';
import { FandomType } from 'generated/prisma/enums';
export class CreateFandomDto {
  @IsString()
  @MaxLength(128)
  name!: string;

  @IsOptional()
  @IsEnum(FandomType)
  type: FandomType = FandomType.NOVEL;

  @IsOptional()
  @IsString()
  description?: string;
}
