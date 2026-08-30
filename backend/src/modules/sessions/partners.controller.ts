import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
} from '@nestjs/common';
import { CreatePartnerDto } from './dto/create-partner.dto';
import { PartnerResponse, PartnersService } from './partners.service';

@Controller('partners')
export class PartnersController {
  constructor(private readonly partnersService: PartnersService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body() dto: CreatePartnerDto): Promise<PartnerResponse> {
    return this.partnersService.create(dto);
  }

  @Get()
  list(): Promise<PartnerResponse[]> {
    return this.partnersService.list();
  }
}
