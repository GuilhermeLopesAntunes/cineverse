import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { LoggerModule } from 'nestjs-pino';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { pinoLoggerOptions } from './common/logger/pino-options';
import { AuthModule } from './modules/auth/auth.module';
import { CatalogModule } from './modules/catalog/catalog.module';
import { ChatModule } from './modules/chat/chat.module';
import { FeedModule } from './modules/feed/feed.module';
import { HealthModule } from './modules/health/health.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { OrdersModule } from './modules/orders/orders.module';
import { PartnerIntegrationModule } from './modules/partner-integration/partner-integration.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { SeatsModule } from './modules/seats/seats.module';
import { SessionsModule } from './modules/sessions/sessions.module';
import { TicketsModule } from './modules/tickets/tickets.module';
import { UsersModule } from './modules/users/users.module';
import { PrismaModule } from './prisma/prisma.module';
import { bullmqConnection } from './queue/bullmq.config';
import { RedisModule } from './redis/redis.module';

@Module({
  imports: [
    LoggerModule.forRoot(pinoLoggerOptions),
    // Registered again here (also in AuthModule) just to make JwtService
    // available to JwtAuthGuard — cheap, stateless, no conflict.
    JwtModule.register({}),
    BullModule.forRoot({ connection: bullmqConnection }),
    PrismaModule,
    RedisModule,
    HealthModule,
    AuthModule,
    UsersModule,
    CatalogModule,
    SessionsModule,
    SeatsModule,
    FeedModule,
    ChatModule,
    PartnerIntegrationModule,
    OrdersModule,
    PaymentsModule,
    TicketsModule,
    NotificationsModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
  ],
})
export class AppModule {}
