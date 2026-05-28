import { Test, TestingModule } from '@nestjs/testing';
import { FandomController } from './fandom.controller';
import { FandomService } from './fandom.service';

describe('FandomController', () => {
  let controller: FandomController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [FandomController],
      providers: [FandomService],
    }).compile();

    controller = module.get<FandomController>(FandomController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
