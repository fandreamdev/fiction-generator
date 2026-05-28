import { Injectable } from '@nestjs/common';
import { CreateFandomDto } from './dto/create-fandom.dto';
import { UpdateFandomDto } from './dto/update-fandom.dto';

@Injectable()
export class FandomService {
  create(userId: number, createFandomDto: CreateFandomDto) {
    console.log(userId, createFandomDto);
    return 'This action adds a new fandom';
  }

  list(userId: number) {
    console.log(userId);
    return `This action returns all fandom`;
  }

  getById(userId: number, id: number) {
    return `This action returns a #${id} fandom`;
  }

  update(id: number, updateFandomDto: UpdateFandomDto) {
    console.log(id, updateFandomDto);

    return `This action updates a #${id} fandom`;
  }

  remove(id: number) {
    return `This action removes a #${id} fandom`;
  }
}
