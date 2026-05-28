import { PartialType } from '@nestjs/swagger';
import { CreateFandomDto } from './create-fandom.dto';

export class UpdateFandomDto extends PartialType(CreateFandomDto) {}
