import { INestApplication } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { accessTokenConfig } from '../src/common/config/jwt.config';
import { AppModule } from './../src/app.module';

describe('AppController (e2e)', () => {
  let app: INestApplication<App>;
  let jwtService: JwtService;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
    jwtService = new JwtService();
  });

  it('/ (GET) without a token is rejected', () => {
    return request(app.getHttpServer()).get('/').expect(401);
  });

  it('/ (GET) with a valid token succeeds', async () => {
    const token = await jwtService.signAsync(
      { sub: 1, email: 'test@example.com' },
      {
        secret: accessTokenConfig.secret,
        expiresIn: accessTokenConfig.expiresIn,
      },
    );

    return request(app.getHttpServer())
      .get('/')
      .set('Authorization', `Bearer ${token}`)
      .expect(200)
      .expect('Hello World!');
  });

  afterEach(async () => {
    await app.close();
  });
});
