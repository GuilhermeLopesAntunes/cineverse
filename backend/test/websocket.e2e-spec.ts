import { INestApplication } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import {
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server as HttpServer, AddressInfo } from 'net';
import { io, Socket as ClientSocket } from 'socket.io-client';
import type { Server } from 'socket.io';
import { accessTokenConfig } from '../src/common/config/jwt.config';
import { RedisIoAdapter } from '../src/websocket/redis-io.adapter';
import { AppModule } from './../src/app.module';

// Minimal test-only gateway — not part of the app. Its only job is proving
// that `server.emit()` called on one instance's Socket.io server reaches a
// client connected to a *different* instance, which only works if the Redis
// adapter (BE-18) is actually wired up; the default in-memory adapter would
// only deliver to sockets on the same process.
@WebSocketGateway()
class TestBroadcastGateway {
  @WebSocketServer()
  server!: Server;

  @SubscribeMessage('broadcast')
  handleBroadcast(@MessageBody() body: unknown): void {
    this.server.emit('broadcast-echo', body);
  }
}

async function createInstance(): Promise<{
  app: INestApplication;
  port: number;
}> {
  const moduleFixture: TestingModule = await Test.createTestingModule({
    imports: [AppModule],
    providers: [TestBroadcastGateway],
  }).compile();

  const app = moduleFixture.createNestApplication();
  const redisIoAdapter = new RedisIoAdapter(app);
  redisIoAdapter.connectToRedis();
  app.useWebSocketAdapter(redisIoAdapter);

  await app.listen(0);
  const httpServer = app.getHttpServer() as HttpServer;
  const port = (httpServer.address() as AddressInfo).port;
  return { app, port };
}

function connectClient(port: number, token?: string): ClientSocket {
  return io(`http://localhost:${port}`, {
    ...(token ? { auth: { token } } : {}),
    transports: ['websocket'],
    forceNew: true,
    reconnection: false,
  });
}

function waitForEvent<T = unknown>(
  socket: ClientSocket,
  event: string,
): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`Timed out waiting for "${event}"`)),
      5000,
    );
    socket.once(event, (payload: T) => {
      clearTimeout(timer);
      resolve(payload);
    });
  });
}

describe('WebSocket infra (e2e)', () => {
  let instanceA: { app: INestApplication; port: number };
  let instanceB: { app: INestApplication; port: number };
  let validToken: string;
  const clients: ClientSocket[] = [];

  beforeAll(async () => {
    [instanceA, instanceB] = await Promise.all([
      createInstance(),
      createInstance(),
    ]);
    validToken = await new JwtService().signAsync(
      { sub: 42, email: 'ws-test@example.com' },
      {
        secret: accessTokenConfig.secret,
        expiresIn: accessTokenConfig.expiresIn,
      },
    );
  });

  afterEach(() => {
    clients.forEach((c) => c.disconnect());
    clients.length = 0;
  });

  afterAll(async () => {
    await instanceA.app.close();
    await instanceB.app.close();
  });

  it('rejects a handshake with no access token', async () => {
    const client = connectClient(instanceA.port);
    clients.push(client);

    const error = await waitForEvent<Error>(client, 'connect_error');
    expect(error.message).toBe('Token de acesso ausente');
  });

  it('rejects a handshake with an invalid access token', async () => {
    const client = connectClient(instanceA.port, 'not-a-real-token');
    clients.push(client);

    const error = await waitForEvent<Error>(client, 'connect_error');
    expect(error.message).toBe('Token de acesso inválido');
  });

  it('accepts a handshake with a valid access token', async () => {
    const client = connectClient(instanceA.port, validToken);
    clients.push(client);

    await waitForEvent(client, 'connect');
    expect(client.connected).toBe(true);
  });

  it('propagates a broadcast from one instance to a client connected on another instance', async () => {
    const clientOnA = connectClient(instanceA.port, validToken);
    const clientOnB = connectClient(instanceB.port, validToken);
    clients.push(clientOnA, clientOnB);

    await Promise.all([
      waitForEvent(clientOnA, 'connect'),
      waitForEvent(clientOnB, 'connect'),
    ]);

    const echoOnB = waitForEvent(clientOnB, 'broadcast-echo');
    clientOnA.emit('broadcast', { hello: 'cross-instance' });

    await expect(echoOnB).resolves.toEqual({ hello: 'cross-instance' });
  });
});
