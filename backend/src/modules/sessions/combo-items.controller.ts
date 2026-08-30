import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseIntPipe,
  Post,
} from '@nestjs/common';
import { ComboItemResponse, ComboItemsService } from './combo-items.service';
import { CreateComboItemDto } from './dto/create-combo-item.dto';

@Controller('partners/:partnerId/combos')
export class ComboItemsController {
  constructor(private readonly comboItemsService: ComboItemsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(
    @Param('partnerId', ParseIntPipe) partnerId: number,
    @Body() dto: CreateComboItemDto,
  ): Promise<ComboItemResponse> {
    return this.comboItemsService.create(partnerId, dto);
  }

  @Get()
  list(
    @Param('partnerId', ParseIntPipe) partnerId: number,
  ): Promise<ComboItemResponse[]> {
    return this.comboItemsService.listByPartner(partnerId);
  }
}
