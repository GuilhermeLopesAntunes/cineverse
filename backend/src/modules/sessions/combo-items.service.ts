import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../../prisma/db';
import { CreateComboItemDto } from './dto/create-combo-item.dto';
import { PartnersService } from './partners.service';

export interface ComboItemResponse {
  id: number;
  partnerId: number;
  name: string;
  priceCents: number;
}

const COMBO_ITEM_FIELDS = ['id', 'partnerId', 'name', 'priceCents'] as const;

@Injectable()
export class ComboItemsService {
  constructor(private readonly partnersService: PartnersService) {}

  async create(
    partnerId: number,
    dto: CreateComboItemDto,
  ): Promise<ComboItemResponse> {
    await this.partnersService.findOrThrow(partnerId);
    return db.orm.public.ComboItem.select(...COMBO_ITEM_FIELDS).create({
      partnerId,
      name: dto.name,
      priceCents: dto.priceCents,
    });
  }

  // This is the endpoint that satisfies BE-26's own acceptance criterion —
  // "combo aparece como opção no checkout": the client calls this to render
  // the combo picker before ever building the create-order request.
  async listByPartner(partnerId: number): Promise<ComboItemResponse[]> {
    await this.partnersService.findOrThrow(partnerId);
    return db.orm.public.ComboItem.where({ partnerId })
      .select(...COMBO_ITEM_FIELDS)
      .orderBy((c) => c.id.asc())
      .all();
  }

  async findOrThrow(id: number): Promise<ComboItemResponse> {
    const comboItem = await db.orm.public.ComboItem.where({ id })
      .select(...COMBO_ITEM_FIELDS)
      .first();
    if (!comboItem) {
      throw new NotFoundException(`Combo ${id} não encontrado`);
    }
    return comboItem;
  }
}
