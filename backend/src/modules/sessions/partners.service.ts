import { Injectable, NotFoundException } from '@nestjs/common';
import { haversineDistanceKm } from '../../common/geo/haversine';
import { db } from '../../prisma/db';
import { CreatePartnerDto } from './dto/create-partner.dto';

export interface PartnerResponse {
  id: number;
  name: string;
  apiConfig: string | null;
  latitude: number;
  longitude: number;
  createdAt: string;
}

export interface NearestPartnerResult {
  partner: PartnerResponse;
  distanceKm: number;
}

const PARTNER_FIELDS = [
  'id',
  'name',
  'apiConfig',
  'latitude',
  'longitude',
  'createdAt',
] as const;

@Injectable()
export class PartnersService {
  create(dto: CreatePartnerDto): Promise<PartnerResponse> {
    return db.orm.public.CinemaPartner.select(...PARTNER_FIELDS).create({
      name: dto.name,
      apiConfig: dto.apiConfig ?? null,
      latitude: dto.latitude,
      longitude: dto.longitude,
    });
  }

  async list(): Promise<PartnerResponse[]> {
    return db.orm.public.CinemaPartner.select(...PARTNER_FIELDS)
      .orderBy((p) => p.id.asc())
      .all();
  }

  async findOrThrow(id: number): Promise<PartnerResponse> {
    const partner = await db.orm.public.CinemaPartner.where({ id })
      .select(...PARTNER_FIELDS)
      .first();
    if (!partner) {
      throw new NotFoundException(`Parceiro ${id} não encontrado`);
    }
    return partner;
  }

  // Straight-line nearest among ALL partners — fine while there's a handful
  // (MVP has exactly one); see haversine.ts for why this isn't PostGIS.
  async findNearest(
    lat: number,
    lng: number,
  ): Promise<NearestPartnerResult | null> {
    const partners = await this.list();
    if (partners.length === 0) {
      return null;
    }

    let nearest = partners[0];
    let nearestDistanceKm = haversineDistanceKm(
      lat,
      lng,
      nearest.latitude,
      nearest.longitude,
    );

    for (const partner of partners.slice(1)) {
      const distanceKm = haversineDistanceKm(
        lat,
        lng,
        partner.latitude,
        partner.longitude,
      );
      if (distanceKm < nearestDistanceKm) {
        nearest = partner;
        nearestDistanceKm = distanceKm;
      }
    }

    return { partner: nearest, distanceKm: nearestDistanceKm };
  }
}
