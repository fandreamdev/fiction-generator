import { Injectable, NestMiddleware } from '@nestjs/common';
import type { Request, Response, NextFunction } from 'express';
import { DEMO_USER_ID } from './constants';

@Injectable()
export class DemoUserMiddleware implements NestMiddleware {
  use(req: Request, _res: Response, next: NextFunction) {
    req.userId = DEMO_USER_ID;
    next();
  }
}
