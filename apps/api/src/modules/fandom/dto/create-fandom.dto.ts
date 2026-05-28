import { IsString, MaxLength, IsOptional, IsIn } from 'class-validator';
export class CreateFandomDto {
  @IsString()
  @MaxLength(128)
  name!: string;

  @IsOptional()
  @IsIn(['novel', 'anime', 'game', 'film', 'other'])
  type?: string = 'novel';

  @IsOptional()
  @IsString()
  description?: string;
}
