import { Module } from '@nestjs/common';
import { ComboItemsController } from './combo-items.controller';
import { ComboItemsService } from './combo-items.service';
import { PartnersController } from './partners.controller';
import { PartnersService } from './partners.service';
import { RoomsController } from './rooms.controller';
import { RoomsService } from './rooms.service';
import { SessionsController } from './sessions.controller';
import { SessionsService } from './sessions.service';

@Module({
  controllers: [
    PartnersController,
    RoomsController,
    SessionsController,
    ComboItemsController,
  ],
  providers: [
    PartnersService,
    RoomsService,
    SessionsService,
    ComboItemsService,
  ],
  exports: [PartnersService, RoomsService, ComboItemsService],
})
export class SessionsModule {}
