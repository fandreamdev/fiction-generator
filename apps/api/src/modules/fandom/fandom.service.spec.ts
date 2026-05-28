import { Test, TestingModule } from '@nestjs/testing';
import { FandomService } from './fandom.service';

describe('FandomService', () => {
  let service: FandomService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [FandomService],
    }).compile();

    service = module.get<FandomService>(FandomService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
