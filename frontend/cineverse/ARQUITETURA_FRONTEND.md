# Arquitetura de Frontend — CineVerse (Flutter + BLoC)

> Desenho técnico do cliente. O backend já existe e está implementado (`../backend`); este documento parte da API real, não de uma API desejada. Toda afirmação sobre o servidor pode ser conferida no arquivo citado.

**Data:** 29/08/2026 · **Alvo:** Android e iOS · **Gerência de estado:** `flutter_bloc`

---

## Sumário

1. [Visão geral](#1-visão-geral)
2. [Arquitetura em camadas](#2-arquitetura-em-camadas)
3. [Organização do código](#3-organização-do-código)
4. [Modelagem de estado com BLoC](#4-modelagem-de-estado-com-bloc)
5. [Catálogo de Blocs](#5-catálogo-de-blocs)
6. [Navegação](#6-navegação)
7. [Camada de rede: contrato com a API](#7-camada-de-rede-contrato-com-a-api)
8. [Camada de tempo real](#8-camada-de-tempo-real)
9. [Autenticação e sessão](#9-autenticação-e-sessão)
10. [Tratamento de erro](#10-tratamento-de-erro)
11. [Atritos conhecidos com a API atual](#11-atritos-conhecidos-com-a-api-atual)
12. [Escopo de telas](#12-escopo-de-telas)
13. [Fluxos críticos](#13-fluxos-críticos)
14. [Modelo de dados do cliente](#14-modelo-de-dados-do-cliente)
15. [Estratégia de testes](#15-estratégia-de-testes)
16. [Requisitos não funcionais](#16-requisitos-não-funcionais)
17. [Decisões arquiteturais registradas](#17-decisões-arquiteturais-registradas)

---

## 1. Visão geral

O cliente Flutter consome um backend NestJS já pronto, composto de:

- **API REST** em `/api/v1`, com 35 rotas de domínio, autenticação JWT obrigatória por padrão
- **Dois namespaces WebSocket** (Socket.io): `/chat` e `/seats`
- **Um endpoint fora do prefixo**: `GET /health`

O app tem três frentes funcionais, e a arquitetura precisa acomodar as três com o mesmo esqueleto:

| Frente | Natureza | Exigência arquitetural |
|---|---|---|
| **Social** (feed, chat) | Leitura paginada + tempo real | Paginação infinita; socket com ciclo de vida por tela |
| **Descoberta** (catálogo, sessões próximas) | Leitura + permissão de dispositivo | Cache em memória para junções que a API não faz; tratamento de permissão negada |
| **Compra** (assentos, pedido, pagamento, ingresso) | Escrita com concorrência e prazo | Estado com cronômetro (lock de 5 min), *polling* de pagamento, mapa atualizado por WS |

A terceira frente é a que dita o desenho: é a única com **estado compartilhado entre usuários mudando enquanto a tela está aberta**.

---

## 2. Arquitetura em camadas

```
┌──────────────────────────────────────────────────────────────────┐
│  APRESENTAÇÃO                                                    │
│  Pages e Widgets  ·  BlocBuilder / BlocListener / BlocSelector    │
│  Widget não conhece repositório. Só dispara evento e lê estado.  │
└───────────────────────────┬──────────────────────────────────────┘
                            │ evento ↓        estado ↑
┌───────────────────────────▼──────────────────────────────────────┐
│  BLOC                                                            │
│  Traduz intenção do usuário e evento externo (WS, timer) em      │
│  chamadas ao repositório e num único objeto de estado.           │
│  Não conhece dio, JSON, DioException nem Socket.                 │
└───────────────────────────┬──────────────────────────────────────┘
                            │ entidade de domínio / Failure
┌───────────────────────────▼──────────────────────────────────────┐
│  DOMÍNIO                                                         │
│  Entidades (Movie, Session, Seat, Order, Review, ...)            │
│  Interfaces de repositório (abstract)                            │
│  Failure (sealed)                                                │
└───────────────────────────┬──────────────────────────────────────┘
                            │ implementado por
┌───────────────────────────▼──────────────────────────────────────┐
│  DADOS                                                           │
│  RepositoryImpl — traduz DTO→entidade, erro→Failure,             │
│                   e faz as junções que a API não faz             │
│  Api (dio)          ·  Socket (socket_io_client)                 │
│  Models (fromJson espelhando a resposta literal do backend)      │
└───────────────────────────┬──────────────────────────────────────┘
                            │ HTTP / WebSocket
┌───────────────────────────▼──────────────────────────────────────┐
│  BACKEND NestJS (../backend) — REST /api/v1 + Socket.io          │
└──────────────────────────────────────────────────────────────────┘
```

**Por que sem camada de *usecase*.** A documentação oficial do `bloc` e o padrão da Very Good Ventures descrevem `data provider → repository → bloc → UI`. Introduzir uma classe por operação (`GetMoviesUseCase`, `LockSeatsUseCase`) só faria sentido se houvesse regra de negócio que não pertence a nenhum repositório — e não há: a regra de verdade deste domínio (atomicidade da reserva, idempotência do pagamento, assinatura do ingresso) **está no servidor**, onde tem que estar. Replicar essa regra no cliente seria duplicá-la em lugar errado. O repositório do app faz tradução e junção; o Bloc faz orquestração de tela. É o suficiente, e cada camada tem uma responsabilidade nomeável.

**O que o cliente deliberadamente não faz:** validar disponibilidade de assento localmente, calcular total de pedido como fonte de verdade, decidir se um ingresso é válido. Tudo isso é decidido pelo backend, e o app **exibe** o resultado. O total do pedido é calculado localmente **apenas para prévia na tela**; o valor cobrado é sempre o `totalAmountCents` que o servidor devolveu.

---

## 3. Organização do código

```
lib/
├── main.dart
├── app/
│   ├── app.dart                    MaterialApp.router, BlocProviders globais
│   ├── router.dart                 go_router + redirect por sessão
│   ├── theme.dart
│   └── bloc_observer.dart
├── core/
│   ├── api/
│   │   ├── api_client.dart         Dio configurado (baseUrl, timeouts)
│   │   ├── auth_interceptor.dart   Injeta Bearer; 401 → encerra sessão
│   │   └── api_exception.dart      Erro do backend já parseado
│   ├── ws/
│   │   └── socket_factory.dart     Cria socket por namespace com token
│   ├── storage/
│   │   └── token_storage.dart      flutter_secure_storage
│   ├── error/
│   │   ├── failure.dart            sealed class Failure
│   │   └── failure_mapper.dart     DioException/status → Failure
│   ├── di/injector.dart
│   ├── utils/
│   │   ├── money.dart              centavos → String pt_BR
│   │   ├── seat_code.dart          "A12" → (fileira A, posição 12)
│   │   └── paginated.dart          Paginated<T> genérico
│   └── widgets/                    AppErrorView, AppLoader, EmptyState...
└── features/
    ├── auth/          Login, cadastro, estado global de sessão
    ├── profile/       Perfil e gêneros favoritos
    ├── catalog/       Filmes em cartaz (fonte também das junções)
    ├── sessions/      Cinema mais próximo e sessões
    ├── seats/         Mapa de assentos em tempo real e reserva
    ├── orders/        Checkout e histórico de pedidos
    ├── payments/      Pix, carteira, cartão
    ├── tickets/       Validação de QR (e exibição, quando desbloqueada)
    ├── feed/          Resenhas, spoiler, compartilhamento
    ├── chat/          Salas e mensagens em tempo real
    ├── notifications/ Registro de push token
    └── demo/          Ferramentas de demonstração (opcional, ver § 12.3)
```

**Regra de dependência entre features:** uma feature pode depender do **repositório** de outra (ex.: `feed` usa `CatalogRepository` para resolver título de filme), nunca do Bloc ou da página de outra. Dependência entre Blocs é sinal de que a junção deveria estar num repositório.

---

## 4. Modelagem de estado com BLoC

### 4.1 Formato único de estado

Uma classe por Bloc, com `status`, `Equatable` e `copyWith`:

```dart
enum StateStatus { initial, loading, success, failure }
```

**Justificativa (vale na defesa do trabalho):** o mapa de assentos recebe `seat_locked` / `seat_released` / `seat_sold` por WebSocket enquanto o usuário está escolhendo. Com estados `sealed` separados (`SeatMapLoading`, `SeatMapLoaded`), toda atualização obrigaria a escolher entre descartar os dados (tela pisca, seleção do usuário se perde) ou criar estados híbridos (`SeatMapLoadedRefreshing`) que multiplicam casos. Com um estado único, `status: loading` convive com `seats` já preenchido, e a UI decide se mostra um indicador discreto ou uma tela cheia de carregamento.

O mesmo formato vale para telas simples, por consistência: **um padrão para todos os Blocs** vale mais que o ótimo local de cada um.

### 4.2 Onde `sealed` é usado

Em `Failure` (`core/error/failure.dart`), onde o *pattern matching* exaustivo do Dart 3 garante em tempo de compilação que nenhum tipo de falha ficou sem tratamento na UI:

```dart
switch (state.failure!) {
  NetworkFailure()      => 'Sem conexão. Verifique sua internet.',
  UnauthorizedFailure() => 'Sua sessão expirou. Entre novamente.',
  ConflictFailure(:final message) => message,
  ValidationFailure(:final messages) => messages.join('\n'),
  _ => 'Não foi possível concluir. Tente de novo.',
}
```

### 4.3 Eventos vindos de fora do usuário

WebSocket e *timer* de polling **não** chamam `emit` diretamente. Eles adicionam evento ao Bloc:

```dart
_socket.on('seat_locked', (data) => add(SeatLockedReceived.fromJson(data)));
```

Assim toda mudança de estado passa pelo mesmo funil, aparece no `BlocObserver`, e é testável com `bloc_test` sem simular socket real. Toda inscrição é cancelada em `close()`.

---

## 5. Catálogo de Blocs

| Bloc / Cubit | Feature | Escopo | Responsabilidade | Fonte de eventos externos |
|---|---|---|---|---|
| `AuthBloc` | auth | **Global** (app inteiro) | Estado da sessão: desconhecido → autenticado/anônimo. Login, cadastro, logout, expiração | Interceptor 401, `connect_error` do socket |
| `ProfileCubit` | profile | Tela | Carrega perfil (trata 404 como vazio) e salva gêneros (*full-replace*) | — |
| `CatalogBloc` | catalog | Tela + cache | Lista paginada de filmes; mantém cache em memória usado por outras features | — |
| `NearbySessionsBloc` | sessions | Tela | Permissão de localização → coordenadas → parceiro mais próximo + sessões | `geolocator` |
| `SeatMapBloc` | seats | Tela | Snapshot REST + atualizações WS + seleção do usuário + cronômetro do lock | Socket `/seats`, timer |
| `CheckoutBloc` | orders | Fluxo | Orquestra os 3 passos: reserva → pedido → pagamento | Timer do lock |
| `OrdersBloc` | orders | Tela | Histórico paginado de pedidos | — |
| `PaymentBloc` | payments | Tela | Cria cobrança; para Pix, faz *polling* do status | Timer de polling |
| `FeedBloc` | feed | Tela | Feed paginado; revelação de spoiler item a item | — |
| `ReviewComposerCubit` | feed | Tela | Publicação de resenha | — |
| `ChatRoomsBloc` | chat | Tela | Lista paginada de salas | — |
| `ChatRoomBloc` | chat | Tela | Histórico paginado + envio + recepção em tempo real | Socket `/chat` |
| `TicketScannerBloc` | tickets | Tela | Leitura de QR pela câmera + validação | `mobile_scanner` |
| `PushTokenCubit` | notifications | Bootstrap | Registra token do dispositivo após login | — |

`AuthBloc` é o **único** Bloc global. Todos os outros são criados por rota e destruídos com ela.

---

## 6. Navegação

`go_router`, com `refreshListenable` ligado ao `AuthBloc` e `redirect` central.

```
/splash                       Verifica token guardado, decide destino
/login  ·  /register          Públicas
/                             Shell com barra inferior (4 abas)
├── /catalog                  Filmes em cartaz
│   └── /catalog/:movieId     Detalhe (a partir do cache do catálogo)
├── /nearby                   Cinema mais próximo + sessões  ← entrada da compra
│   └── /sessions/:sessionId/seats            Mapa de assentos (WS)
│       └── /checkout                          Combos + confirmação
│           └── /checkout/payment              Método e pagamento
│               └── /checkout/success          Confirmação
├── /feed                     Resenhas
│   ├── /feed/new             Publicar
│   └── /feed/:reviewId       Detalhe, revelar spoiler, compartilhar
└── /profile                  Perfil, gêneros, pedidos, sair
    ├── /profile/orders       Histórico
    │   └── /profile/orders/:orderId
    └── /profile/scanner      Leitor de ingresso (RF-14)
/chat                         Salas
└── /chat/:roomId             Conversa (WS)
```

**Regra de redirecionamento:** qualquer rota que não seja `/login`, `/register` ou `/splash` exige sessão. Sessão expirada (401 em qualquer requisição) → `AuthBloc` emite anônimo → `go_router` redireciona para `/login` **de qualquer lugar do app**, inclusive do meio do checkout.

**Consequência desagradável, mas honesta:** sem endpoint de refresh, uma sessão de compra que ultrapasse 15 minutos é interrompida no meio. O cronômetro do lock (5 min) é menor que isso, então o caso normal de checkout cabe dentro de um access token — mas um usuário que deixe o app aberto e volte depois cai no login. Está registrado como `[BLOQUEADO-BACKEND]`.

**Por que `/nearby` é a entrada da compra e não `/catalog`:** só `GET /sessions/nearby` devolve o `partnerId`, necessário para listar combos no checkout (`GET /partners/:partnerId/combos`). Entrando pelo catálogo, o app teria um `movieId` e nenhum caminho até o parceiro — `GET /sessions` não devolve `partnerId` e não existe `GET /rooms/:id`. A navegação foi desenhada a partir da API real, não do contrário.

---

## 7. Camada de rede: contrato com a API

Base: `{API_BASE_URL}/api/v1`. `Authorization: Bearer <accessToken>` em tudo, exceto o marcado como público.

### 7.1 Autenticação — `features/auth`

| Método | Rota | Corpo | Resposta |
|---|---|---|---|
| POST | `/auth/register` | `{email, password, name?}` | `201` `{id, email, name, createdAt}` |
| POST | `/auth/login` | `{email, password}` | `200` `{accessToken, refreshToken}` |

Senha: mínimo 8, **máximo 72** caracteres (o backend limita porque o bcrypt trunca acima disso) — validar no formulário para o usuário não descobrir isso via 400.
E-mail duplicado → `409`. Credencial errada → `401` com mensagem genérica (o backend não diferencia "não existe" de "senha errada", por design de segurança — a UI **não deve** tentar adivinhar qual foi).

### 7.2 Perfil — `features/profile`

| Método | Rota | Observação |
|---|---|---|
| GET | `/users/me/profile` | `{userId, favoriteGenres: string[]}` · **`404` quando ainda não existe** — tratar como perfil vazio, não como erro |
| PUT | `/users/me/profile` | `{favoriteGenres: string[]}` (máx. 20, únicos) · **substituição total**, não *diff* |

### 7.3 Catálogo — `features/catalog`

| Método | Rota | Resposta |
|---|---|---|
| GET | `/catalog/movies?page=&pageSize=` | `{items:[{id, tmdbId, title, synopsis, posterUrl, cachedAt}], page, pageSize, total, totalPages}` |

`pageSize` entre 1 e 50 (default 20); ordenação por título. `posterUrl` já vem completa (CDN do TMDB) ou `null`. Não existe `GET /catalog/movies/:id` — o detalhe é montado a partir do item já carregado.

### 7.4 Sessões e parceiro — `features/sessions`

| Método | Rota | Resposta |
|---|---|---|
| GET | `/sessions/nearby?lat=&lng=` | `{partner:{id, name, distanceKm}, sessions:[{id, movieId, roomId, datetime, priceCents}]}` · `404` se nenhum parceiro cadastrado |
| GET | `/sessions?roomId=` | Array de sessão (sem paginação) |
| GET | `/partners/:partnerId/combos` | Array `{id, partnerId, name, priceCents}` |

`nearby` já filtra sessões futuras. Guardar `partner.id` no estado do fluxo de compra: é a única fonte do `partnerId`.

### 7.5 Assentos — `features/seats`

| Método | Rota | Resposta |
|---|---|---|
| GET | `/sessions/:sessionId/seats/map` | Array `{seatId, code, status:"available"\|"locked"\|"sold"}` |
| POST | `/sessions/:sessionId/seats/lock` | `{seatIds:[...]}` → `{success, reason?}` · máx. 20 assentos |
| POST | `/sessions/:sessionId/seats/release` | `{seatIds:[...]}` → `{releasedSeatIds:[...]}` |

`lock` é **tudo ou nada**: ou reserva todos, ou nenhum, com `reason` explicando. `success:false` **não** é erro HTTP — vem `200`/`201` com `success:false`. O repositório precisa tratar isso como resultado de domínio, não como falha.

`release` devolve **só o que foi realmente liberado** — se o usuário não detinha um assento, ele não aparece na lista. A UI reflete a lista devolvida, nunca a lista enviada.

### 7.6 Pedido — `features/orders`

| Método | Rota | Corpo / Resposta |
|---|---|---|
| POST | `/orders` | `{sessionId, items:[{seatId, comboItemId?}]}` → `201` `{id, userId, sessionId, status, totalAmountCents, createdAt, items:[...]}` |
| GET | `/orders?page=&pageSize=` | Paginado |
| GET | `/orders/:id` | `403` se for de outro usuário (não `404`) |

**`409` é o caso importante:** significa que o assento não está reservado pelo usuário — quase sempre porque o lock de 5 minutos expirou. A mensagem do backend lista os assentos problemáticos. A UI deve voltar ao mapa, não repetir a requisição.

Combo de parceiro diferente → `400`. Combo inexistente → `404`.

### 7.7 Pagamento — `features/payments`

| Método | Rota | Corpo / Resposta |
|---|---|---|
| POST | `/orders/:orderId/payments` | `{method:"pix"}` → `201` `{..., status:"pending", copyPasteCode}` |
| | | `{method:"apple_pay"\|"google_pay"\|"card", token}` → `201` `{..., status:"paid"\|"failed"}` |
| GET | `/orders/:orderId/payments` | Array de pagamento — **é aqui que o app descobre que o Pix foi pago** |

Dois comportamentos distintos, e a UI precisa refletir isso:

- **Pix:** assíncrono. Devolve `copyPasteCode` para renderizar como QR e oferecer "copiar". A confirmação chega ao **backend** por webhook; o app descobre por *polling* em `GET /orders/:orderId/payments`.
- **Carteira/cartão:** síncrono. O `status` na resposta já é final. Não há polling.

`409` se o pedido já tiver pagamento — **um pagamento por pedido**, sem nova tentativa. Se falhar, o pedido fica travado nesse estado: a UI deve informar isso com clareza em vez de oferecer "tentar de novo" que sempre dará `409`.

**Nenhum campo de cartão existe no DTO do backend.** Enviar `cardNumber`/`cvv` resulta em `400` (`"property cardNumber should not exist"`). O app envia apenas um `token` opaco. Sem SDK real de gateway no MVP, esse token é um identificador simulado gerado no cliente — e a tela deve deixar explícito que é simulação, nunca imitar um formulário de cartão real pedindo dados que não serão usados.

### 7.8 Ingresso — `features/tickets`

| Método | Rota | Resposta |
|---|---|---|
| POST | `/tickets/validate` | `{qrCodePayload}` → **sempre `200`** `{valid, reason?, ticket?}` |

Nunca lança erro: QR forjado, inexistente ou já usado devolve `200` com `valid:false` e `reason`. É intencional no backend — ler um código ruim na porta é tráfego normal de leitor, não erro de servidor. A UI **não** deve tratar `valid:false` como falha de rede.

**Não existe rota de leitura de ingresso.** Ver § 11, atrito 1.

### 7.9 Social — `features/feed` e `features/chat`

| Método | Rota | Observação |
|---|---|---|
| POST | `/reviews` | `{movieId, text, rating:1-5, hasSpoiler?}` → devolve o texto real ao próprio autor |
| GET | `/reviews?page=&pageSize=` | Paginado, mais recentes primeiro · **`text` vem `null` quando `hasSpoiler:true`** |
| GET | `/reviews/:id/reveal` | Texto real |
| GET | `/reviews/:id/share` | `{url, title, text}` para a *share sheet* nativa |
| POST | `/chat/rooms` | `{type:"individual"\|"group", memberIds:[...]}` · o criador entra sozinho; `individual` é *get-or-create* |
| GET | `/chat/rooms?page=&pageSize=` | Paginado |
| GET | `/chat/rooms/:roomId/messages` | Paginado, `createdAt desc` · `403` se não for membro |

A ofuscação de spoiler é feita **no servidor**: o `text` já chega `null`. O app não precisa (nem deve) esconder texto que recebeu — ele nunca recebe. A tela mostra o marcador de spoiler e um botão que chama `reveal`.

### 7.10 Notificações — `features/notifications`

| Método | Rota | Resposta |
|---|---|---|
| POST | `/push-tokens` | `{token, platform:"ios"\|"android"}` → **`200`** (não 201; reregistrar é idempotente) |
| POST | `/notifications/broadcast` | `{title, body}` → `{sentTo}` · **sem UI no app do usuário final** (ver § 12.3) |

`platform` aceita apenas `ios` e `android`; `web` retorna `400`.

### 7.11 Infraestrutura

| Método | Rota | Uso no app |
|---|---|---|
| GET | `/health` (**fora** de `/api/v1`, público) | Tela de diagnóstico e verificação no splash quando a rede falha |

---

## 8. Camada de tempo real

### 8.1 Conexão

```dart
IO.io(
  '$baseUrl/seats',                       // ou /chat
  IO.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': accessToken})    // convenção do Socket.io, lida pelo backend
      .disableAutoConnect()
      .build(),
);
```

O backend valida esse token no handshake para **todo** namespace (`../backend/src/websocket/ws-auth.middleware.ts`). Handshake sem token ou com token inválido é rejeitado — chega ao cliente como `connect_error`.

### 8.2 Namespace `/seats`

| Direção | Evento | Payload |
|---|---|---|
| envia | `joinSession` | `{sessionId}` |
| envia | `lockSeat` / `releaseSeat` | `{sessionId, seatId}` |
| recebe | `seat_locked` / `seat_released` / `seat_sold` | `{sessionId, seatId}` |
| recebe (**só quem tentou**) | `lockRejected` | `{sessionId, seatId, reason}` |
| recebe | `exception` | `{status, message}` |

**Distinção que a UI precisa respeitar:** `seat_locked` chega para todo mundo na sessão, inclusive para quem travou. `lockRejected` chega **apenas** para quem perdeu a disputa. Um snackbar de "assento indisponível" pertence ao segundo, nunca ao primeiro.

Para reserva de **grupo**, usar o endpoint REST `POST .../seats/lock`, não o evento WS: o REST é atômico para N assentos e devolve uma resposta definitiva; o evento WS trava um assento por vez, sem garantia de conjunto. O evento WS serve para a interação de "tocar num assento" quando a seleção é de um só.

### 8.3 Namespace `/chat`

| Direção | Evento | Payload |
|---|---|---|
| envia | `joinRoom` | `{roomId}` |
| envia | `sendMessage` | `{roomId, content}` (1 a 2000 caracteres) |
| recebe | `newMessage` | `{id, roomId, senderId, content, createdAt}` |
| recebe | `exception` | `{status, message}` |

O remetente **também** recebe `newMessage` da própria mensagem (o backend garante isso). Logo: **não** inserir a mensagem otimisticamente na lista sem chave de deduplicação, ou ela aparecerá duas vezes. Padrão adotado: inserir localmente com id temporário e substituir quando o `newMessage` correspondente chegar.

### 8.4 Ciclo de vida

Socket é aberto no `Bloc` da tela e fechado em `close()`. Ao voltar do *background*, o Socket.io reconecta sozinho — mas **o `joinSession`/`joinRoom` precisa ser reenviado**, porque as salas do servidor não sobrevivem à reconexão. Tratar `onConnect` reenviando o *join*.

Como o mapa pode ter mudado durante a desconexão, o `SeatMapBloc` **refaz o snapshot REST** ao reconectar, em vez de confiar apenas nos eventos perdidos.

---

## 9. Autenticação e sessão

```
┌──────────┐  token guardado?  ┌──────────────┐
│ /splash  ├──────────────────►│ /catalog     │  sessão válida
└────┬─────┘                   └──────────────┘
     │ não                            ▲
     ▼                                │ login OK
┌──────────┐                          │
│ /login   ├──────────────────────────┘
└──────────┘
     ▲
     │ 401 em qualquer requisição, ou connect_error no socket
     │ (AuthBloc → anônimo → go_router redireciona de qualquer rota)
```

- Token guardado em `flutter_secure_storage` (Keychain/Keystore).
- O `AuthInterceptor` injeta `Authorization` e, ao ver `401`, limpa o armazenamento e notifica o `AuthBloc`.
- **Não há renovação de token.** O `refreshToken` é armazenado porque o backend o emite, e para que o dia da implementação de `POST /auth/refresh` exija mudança num só arquivo. Enquanto isso, 15 minutos é o tempo de vida da sessão ativa.
- Logout: apaga o armazenamento e fecha sockets abertos. Não há endpoint de logout no backend (JWT é *stateless*) — o token permanece tecnicamente válido até expirar, o que é inerente a JWT sem *blocklist* e está registrado como limitação.

---

## 10. Tratamento de erro

### 10.1 Corpo de erro do backend

```json
{
  "statusCode": 409,
  "error": "Conflict",
  "message": "Reserve o(s) assento(s) antes de finalizar a compra: 12, 13",
  "requestId": "3f2a...",
  "timestamp": "2026-08-29T16:04:00.000Z",
  "path": "/api/v1/orders"
}
```

`message` é **`string` ou `List<String>`** — array quando a validação global rejeita o corpo. O parser trata os dois; tratar só um produz texto ilegível na tela.

### 10.2 Mapeamento para `Failure`

| Status | `Failure` | Comportamento padrão de UI |
|---|---|---|
| sem resposta / timeout | `NetworkFailure` | Tela ou banner com "tentar de novo" |
| 400 | `ValidationFailure(messages)` | Mensagens junto aos campos do formulário |
| 401 | `UnauthorizedFailure` | Encerra sessão, vai para login |
| 403 | `ForbiddenFailure` | "Você não tem acesso a este recurso" |
| 404 | `NotFoundFailure` | Estado vazio, quando fizer sentido (perfil, parceiro) |
| 409 | `ConflictFailure(message)` | Mostrar a mensagem do backend — ela é específica e útil |
| 5xx | `ServerFailure` | Mensagem genérica; o backend não manda detalhe, por design |

**Regra:** em `409`, exibir a mensagem do servidor. É o único status em que o backend produz texto realmente informativo para o usuário final (assentos não reservados, pedido já pago, e-mail em uso). Nos demais, usar texto próprio do app — mensagens de 400/500 não são escritas para usuário final.

O `requestId` vai para o log local do app em toda falha. É o mesmo identificador que aparece no log estruturado do backend.

---

## 11. Atritos conhecidos com a API atual

Levantados por leitura do código do servidor. Cada um traz o impacto e a decisão tomada. **Nenhum deles deve ser contornado com dado falso no cliente.**

### Atrito 1 — O app não consegue exibir o ingresso comprado `[BLOQUEADO-BACKEND]`

**O que acontece:** `PaymentsService.settlePaidOrder` gera um `Ticket` por assento, com `qrCodePayload` (JWT assinado). Mas **nenhuma rota devolve ticket**: `TicketsController` só expõe `POST /tickets/validate`, e a resposta de pagamento não inclui o payload.

**Impacto:** a tela "meu ingresso" — o artefato final da compra, RF-13 do ponto de vista do usuário — **não pode ser construída**. O QR existe no banco e nunca sai de lá.

**Decisão:** implementar tudo até a confirmação de compra; a tela de ingresso fica com estado explícito de indisponibilidade ("ingresso gerado — exibição indisponível nesta versão"), **não** com um QR inventado no cliente. O leitor de QR (RF-14) é implementado normalmente e demonstrado com um payload obtido diretamente do banco durante a demonstração.

**Destrava com:** uma rota de backend `GET /orders/:orderId/tickets` (ou incluir os tickets na resposta de `GET /orders/:id`). É uma task pequena no servidor — algo como quinze linhas em `TicketsService`/`OrdersService`. Vale conversar com o orientador sobre incluí-la no backend antes da entrega, porque é o que fecha o fluxo de ponta a ponta.

### Atrito 2 — Não existe busca de usuário

**O que acontece:** `POST /chat/rooms` exige `memberIds` numéricos, e não há endpoint para listar ou procurar usuários.

**Decisão (que virou desenho, não gambiarra):** o chat é iniciado **a partir do autor de uma resenha**. O feed devolve `userId` em cada item, então "conversar com quem escreveu" é o caminho natural — e é o único caminho tecnicamente possível. Chat em grupo é criado a partir de uma conversa individual existente, adicionando outro autor conhecido. Não existe tela de "novo chat" com campo de busca, porque não existe busca.

### Atrito 3 — Resenha não traz autor nem título do filme

**O que acontece:** `GET /reviews` devolve `userId` e `movieId`, nada mais.

**Decisão:** o `FeedRepository` cruza `movieId` com o cache do `CatalogRepository` para exibir título e pôster. **O nome do autor é impossível** — não há rota que traduza `userId` em nome. A UI mostra um identificador anônimo consistente ("Cinéfilo #42") em vez de nome, e isso é declarado como limitação, não escondido.

### Atrito 4 — `partnerId` só existe em `/sessions/nearby`

**O que acontece:** `GET /sessions` devolve `roomId`, e não há `GET /rooms/:id` para chegar ao parceiro. Sem `partnerId`, não há como listar combos.

**Decisão:** o fluxo de compra **entra por `/nearby`**, que devolve parceiro e sessões juntos, e o `partnerId` é carregado no estado do checkout. Ver § 6.

### Atrito 5 — Feed não filtra por filme

**O que acontece:** `GET /reviews` é global, sem `?movieId=`.

**Decisão:** a tela de detalhe do filme mostra as resenhas daquele filme **filtrando as páginas já carregadas**, com aviso honesto de que são as resenhas recentes, não o histórico completo. Não paginar o feed inteiro em busca de um filme — seria carregar o banco todo no cliente.

### Atrito 6 — Confirmação de Pix não chega ao app

**O que acontece:** o webhook vai do provedor para o backend; o app não é notificado.

**Decisão:** *polling* em `GET /orders/:orderId/payments` a cada 3 s, com limite de 5 minutos (o mesmo TTL do lock de assento — depois disso o assento caiu de qualquer forma). Tela mostra o QR, o código copiável e um estado de espera explícito. O polling para ao sair da tela.

### Atrito 7 — Push nunca é entregue

**O que acontece:** `MockPushSender` apenas escreve no log do servidor. Não há Firebase real.

**Decisão:** implementar `POST /push-tokens` de verdade (o backend persiste e transfere posse corretamente). A entrega de notificação é declarada como não verificável nesta versão. Se houver projeto Firebase disponível, o `firebase_messaging` fornece um token real; se não, registra-se um identificador de instalação — o backend aceita qualquer string.

### Atrito 8 — Sem renovação de token

Ver § 9. Sessão dura 15 minutos de token; expirou, é login de novo.

### Atrito 9 — Cadastro administrativo aberto e sem UI prevista

**O que acontece:** `POST /partners`, `/rooms`, `/seats`, `/sessions`, `/combos`, `/notifications/broadcast` e `/tickets/validate` exigem apenas um JWT qualquer — o backend não tem papel de administrador.

**Decisão:** **não** expor essas operações no app do usuário final. Massa de dados é criada por script HTTP versionado em `tool/`. As duas exceções ficam numa área de demonstração explicitamente rotulada (§ 12.3), porque a banca precisa ver RF-14 funcionando.

### Atrito 10 — Sem CORS no backend

Irrelevante para Android/iOS (não são navegadores), impeditivo para Flutter Web. Alvo do projeto é mobile; Flutter Web está fora de escopo por essa razão técnica, e não por preferência.

---

## 12. Escopo de telas

### 12.1 Telas do usuário final

| # | Tela | Requisito | Bloc | Depende de |
|---|---|---|---|---|
| 1 | Splash / decisão de sessão | — | `AuthBloc` | armazenamento seguro |
| 2 | Login | RF-01 | `AuthBloc` | `POST /auth/login` |
| 3 | Cadastro | RF-01 | `AuthBloc` | `POST /auth/register` |
| 4 | Catálogo em cartaz | RF-06 | `CatalogBloc` | `GET /catalog/movies` |
| 5 | Detalhe do filme | RF-06 | (cache) | — |
| 6 | Cinema próximo e sessões | RF-07 | `NearbySessionsBloc` | `GET /sessions/nearby` + GPS |
| 7 | Mapa de assentos | RF-10, RD-02 | `SeatMapBloc` | `GET .../seats/map` + WS `/seats` |
| 8 | Checkout (combos e resumo) | RF-08, RF-09, RF-15 | `CheckoutBloc` | `.../seats/lock`, `/combos`, `POST /orders` |
| 9 | Pagamento | RF-11, RF-12 | `PaymentBloc` | `POST /orders/:id/payments` |
| 10 | Confirmação de compra | RF-08 | — | resposta do pagamento |
| 11 | Meus pedidos | RF-08 | `OrdersBloc` | `GET /orders` |
| 12 | Detalhe do pedido | RF-08 | — | `GET /orders/:id` |
| 13 | Meu ingresso | RF-13 | — | **bloqueada** (atrito 1) |
| 14 | Feed de resenhas | RF-03, RF-04 | `FeedBloc` | `GET /reviews` |
| 15 | Publicar resenha | RF-03 | `ReviewComposerCubit` | `POST /reviews` |
| 16 | Detalhe da resenha (revelar/compartilhar) | RF-04, RF-16 | — | `/reveal`, `/share` |
| 17 | Lista de conversas | RF-05 | `ChatRoomsBloc` | `GET /chat/rooms` |
| 18 | Conversa | RF-05 | `ChatRoomBloc` | `GET .../messages` + WS `/chat` |
| 19 | Perfil e gêneros favoritos | RF-02 | `ProfileCubit` | `GET/PUT /users/me/profile` |

### 12.2 Tela operacional

| # | Tela | Requisito | Observação |
|---|---|---|---|
| 20 | Leitor de ingresso | RF-14, RNF-12 | Câmera + `POST /tickets/validate`. Sem papel de funcionário no backend, fica no perfil, rotulada como simulação de operação de portaria |

### 12.3 Área de demonstração (opcional)

Uma tela oculta, acessível por gesto no perfil, que dispara `POST /notifications/broadcast` e permite colar um `qrCodePayload` manualmente para validar. Existe para a banca ver o comportamento, **não** faz parte do produto. Se for implementada, deve estar visualmente marcada como ferramenta de demonstração — nunca disfarçada de funcionalidade.

---

## 13. Fluxos críticos

### 13.1 Compra de ingresso — o fluxo principal

```
[Nearby]  usuário escolhe sessão      (partnerId guardado no estado)
    ↓
[Mapa]    GET .../seats/map  → snapshot
          socket /seats: joinSession → recebe seat_locked/released/sold ao vivo
          usuário seleciona N assentos (só os "available")
    ↓
[Reserva] POST .../seats/lock {seatIds}     ← tudo ou nada
          success:false → volta ao mapa com a razão; NÃO segue
          success:true  → inicia cronômetro de 5 min
    ↓
[Checkout] GET /partners/:partnerId/combos
           usuário escolhe combo por assento (ou nenhum)
           prévia do total calculada localmente (só exibição)
    ↓
[Pedido]  POST /orders {sessionId, items:[{seatId, comboItemId?}]}
          409 → o lock expirou: volta ao mapa
          201 → totalAmountCents do servidor é o valor oficial
    ↓
[Pagamento]
    ├─ Pix:      POST payments {method:"pix"} → QR + polling a cada 3s
    └─ Carteira/cartão: POST payments {method, token} → status final na resposta
    ↓
[Confirmação]  status "paid" → assentos viram vendidos (chega por WS a quem
               estiver no mapa), tickets gerados no servidor
```

**Três pontos que a UI precisa acertar:**

1. **O cronômetro é obrigatório.** O lock expira em 5 minutos no servidor, sem aviso. Sem contador visível, o usuário descobre com um `409` no fim do checkout.
2. **Sair do checkout deve liberar os assentos.** Chamar `POST .../seats/release` ao abandonar o fluxo — não deixar assento preso até o TTL enquanto outra pessoa tenta comprar.
3. **Um pagamento por pedido.** Pagamento `failed` deixa o pedido travado; a UI informa e oferece iniciar uma nova compra, não "tentar de novo" (que dará `409`).

### 13.2 Mapa de assentos em tempo real

```
SeatMapBloc
  ├─ SeatMapRequested       → GET map (REST)          → status:success, seats
  ├─ socket.on(seat_locked) → add(SeatLockedReceived) → atualiza 1 assento
  ├─ socket.on(seat_sold)   → add(SeatSoldReceived)   → atualiza 1 assento
  ├─ SeatTapped             → alterna seleção local (sem ir ao servidor)
  └─ onConnect (reconexão)  → add(SeatMapRequested)   → ressincroniza snapshot
```

Atualização por evento altera **um assento**, preservando a seleção do usuário. É exatamente o caso que justifica o estado único com `status` (§ 4.1).

**Se um assento selecionado pelo usuário for tomado por outro** (`seat_locked` de terceiro), a UI remove da seleção e avisa. Não deixar seleção fantasma que só falharia na reserva.

### 13.3 Chat

```
ChatRoomBloc
  ├─ MessagesRequested → GET messages (desc, paginado) → inverte para exibir
  ├─ socket joinRoom
  ├─ MessageSubmitted  → socket.emit(sendMessage) + item local com id temporário
  └─ socket.on(newMessage) → add(MessageReceived) → substitui o temporário ou anexa
```

O backend devolve `createdAt desc` (mais recentes primeiro) — a lista de chat exibe na ordem inversa, com `reverse: true` no `ListView` e paginação ao chegar ao topo.

---

## 14. Modelo de dados do cliente

Entidades espelham o contrato do backend (`../backend/src/prisma/contract.prisma`), com apenas os campos que a API realmente devolve:

| Entidade | Campos | Origem |
|---|---|---|
| `AuthSession` | accessToken, refreshToken | `/auth/login` |
| `UserProfile` | userId, favoriteGenres | `/users/me/profile` |
| `Movie` | id, tmdbId, title, synopsis?, posterUrl?, cachedAt | `/catalog/movies` |
| `CinemaPartner` | id, name, distanceKm | `/sessions/nearby` |
| `Session` | id, movieId, roomId, datetime, priceCents | `/sessions*` |
| `ComboItem` | id, partnerId, name, priceCents | `/partners/:id/combos` |
| `Seat` | seatId, code, status, (fileira/posição derivadas do code) | `/seats/map` |
| `Order` | id, sessionId, status, totalAmountCents, createdAt, items | `/orders` |
| `OrderItem` | seatId, comboItemId? | idem |
| `Payment` | id, orderId, method, providerRef, status, createdAt, copyPasteCode? | `/payments` |
| `Review` | id, userId, movieId, text?, rating, hasSpoiler, createdAt | `/reviews` |
| `ChatRoom` | id, type, createdAt | `/chat/rooms` |
| `Message` | id, roomId, senderId, content, createdAt | `/chat/rooms/:id/messages` |
| `TicketValidation` | valid, reason?, ticket? | `/tickets/validate` |
| `Paginated<T>` | items, page, pageSize, total, totalPages | todas as listagens paginadas |

`Review.text` é **anulável de propósito** — `null` significa "spoiler não revelado", não "resenha vazia". O tipo carrega essa semântica: quem usar a entidade é obrigado a tratar o caso.

Sem banco local. Cache é em memória, dentro dos repositórios, com tempo de vida da sessão do app. Persistência local (Isar/Drift/Hive) está fora de escopo: o único ganho seria leitura offline do catálogo, e o requisito de offline não existe.

---

## 15. Estratégia de testes

Espelha a disciplina do backend (184 testes unitários e 11 e2e), adaptada ao cliente:

| Nível | Ferramenta | Escopo | Meta |
|---|---|---|---|
| **Unitário de Bloc** | `bloc_test` + `mocktail` | Sequência de estados para cada evento, incluindo caminhos de falha | **Todo Bloc tem teste** |
| **Unitário puro** | `flutter_test` | `seat_code.dart`, `money.dart`, `failure_mapper.dart`, `fromJson` dos DTOs | Cobrir as regras com armadilha |
| **Widget** | `flutter_test` | Telas com regra visual: mapa de assentos, spoiler oculto/revelado, cronômetro | Telas 7, 8, 9, 14 |
| **Integração** | `integration_test` | Fluxo de compra ponta a ponta contra backend real local | 1 cenário completo |

**Casos que não podem faltar** (são as regras que quebram calado):

- `lock` com `success:false` **não** avança o checkout
- `409` na criação do pedido volta ao mapa em vez de repetir a requisição
- expiração do cronômetro libera a seleção
- `Review` com `hasSpoiler:true` chega com `text:null` e a UI não vaza texto
- `newMessage` do próprio remetente não duplica a mensagem na lista
- `401` em qualquer requisição derruba a sessão e redireciona
- `message` de erro em formato de array é exibido legível
- `GET /users/me/profile` com `404` produz perfil vazio, não tela de erro

---

## 16. Requisitos não funcionais

| RNF | O que cabe ao cliente |
|---|---|
| **RNF-01 / RNF-07** (escala, pico) | Paginação em toda listagem; nenhuma requisição em laço sem limite; polling só enquanto a tela está visível |
| **RNF-06** (payload reduzido) | `pageSize` moderado (20); pôster via `cached_network_image` direto da CDN — o backend não faz proxy de imagem de propósito |
| **RNF-08** (zero duplicidade) | Garantido pelo **servidor**. O cliente não decide disponibilidade: nunca marcar assento como reservado antes da resposta de `lock` |
| **RNF-12** (validação < 500 ms) | Leitor envia o payload lido sem processamento local; a medição é do servidor (~5–10 ms medidos) |
| **RF-05** (mensagem < 2 s) | WebSocket, não polling. Medição do backend em teste ao vivo: ~17 ms |
| **Acessibilidade** | Contraste mínimo, `Semantics` nos assentos (código + estado), alvos de toque ≥ 48 dp — um mapa de assentos é denso por natureza e precisa de atenção aqui |
| **Idioma** | Interface em pt-BR; `intl` com locale fixo. As mensagens de erro do backend já vêm em português |

---

## 17. Decisões arquiteturais registradas

| # | Decisão | Alternativa descartada | Por quê |
|---|---|---|---|
| 1 | `flutter_bloc` | Riverpod, GetX, Provider | Requisito do trabalho. Separação explícita evento→estado, e o `bloc_test` torna a sequência de estados verificável — importante num app com concorrência |
| 2 | Sem camada de *usecase* | Clean Architecture com usecases | A regra de negócio real está no servidor; usecases seriam invólucros de uma linha. `data → repository → bloc → UI` é o padrão oficial do `bloc` |
| 3 | Estado único com `status` | Estados `sealed` por Bloc | O mapa de assentos atualiza por WS enquanto é usado; descartar dados a cada atualização faria a tela piscar e perder a seleção (§ 4.1) |
| 4 | `sealed class Failure` | Exceções propagadas até a UI | *Pattern matching* exaustivo do Dart 3 garante em compilação que nenhuma falha ficou sem tratamento |
| 5 | `fromJson` manual | `json_serializable` | ~20 DTOs pequenos; o mapeamento explícito expõe as peculiaridades da API (`text` anulável, centavos) em vez de escondê-las atrás de codegen |
| 6 | `dio` | `http` | Interceptor: token e tratamento de 401 num ponto só |
| 7 | Entrada da compra por `/nearby` | Entrada pelo catálogo | É o único endpoint que devolve `partnerId`, necessário para combos (§ 11, atrito 4) |
| 8 | Reserva de grupo por REST, não WS | Emitir N `lockSeat` | O REST é atômico para N assentos; N eventos WS não garantem "tudo ou nada" |
| 9 | Socket por tela | Socket global | Ciclo de vida claro, menos bateria; e a reconexão precisa refazer o *join* de qualquer forma |
| 10 | Sem banco local | Isar/Drift/Hive | Não há requisito de offline; cache em memória atende as junções necessárias |
| 11 | Sem UI administrativa | Telas de cadastro no app | O backend não tem papel de administrador; expor isso ao usuário final seria erro de produto, não simplificação |
| 12 | Alvo mobile, sem Flutter Web | Suporte a Web | O backend não habilita CORS — é impedimento técnico verificável, não preferência |
