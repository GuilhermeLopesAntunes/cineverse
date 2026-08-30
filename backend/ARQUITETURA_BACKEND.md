# Arquitetura de Backend — CineVerse (MVP)

> Traduz os RF, RNF, RD, RT e CU do Documento de Levantamento de Requisitos em decisões técnicas de backend. Onde não havia informação explícita nas entrevistas, está marcado como **[inferência]** com a justificativa — valide antes de tratar como definitivo.

## 1. Visão geral

Um backend em Node.js/TypeScript servindo três frentes:
- **API REST** para cadastro, perfil, feed, catálogo, compra, pagamento e QR code
- **Camada WebSocket** para chat em tempo real e sincronização do mapa de assentos
- **Integrações externas**: TMDB (catálogo), sistema de bilheteria do parceiro (mock no MVP), gateway de pagamento, push notifications

## 2. Módulos do sistema

| Módulo | Responsabilidade | RF/RNF relacionados |
|---|---|---|
| `auth` | Cadastro, login, JWT | RF-01 |
| `users` | Perfil, preferências de gênero de filme | RF-02 |
| `feed` | Resenhas, marcação de spoiler, compartilhamento | RF-03, RF-04, RF-16 |
| `chat` | Mensagens em tempo real (grupo/individual), histórico | RF-05 |
| `catalog` | Sincronização e cache de filmes em cartaz (TMDB) | RF-06, RT-02 |
| `sessions` | Sessões de exibição do parceiro, busca hiperlocal | RF-07 |
| `seats` | Mapa de assentos, lock temporário, sync com parceiro | RF-10, RD-02, RNF-08 |
| `orders` | Checkout individual e em grupo, combos | RF-08, RF-09, RF-15 |
| `payments` | Pix, Apple Pay, Google Pay, cartão via gateway | RF-11, RF-12, RD-03 |
| `tickets` | Geração e validação de QR Code | RF-13, RF-14, RNF-12 |
| `notifications` | Push (lembrete de sessão, promoções) | RF-17 |
| `partner-integration` | Camada de abstração para o ERP/bilheteria do parceiro (mock no MVP) | RNF-02, RNF-10 |
| `analytics` **[FORA DE ESCOPO — confirmado pelo usuário, 2026-08-29]** | ~~Painel B2B com dados agregados/anonimizados (DAU/MAU, CAC, churn, GMV)~~ — não existe, era inferência não confirmada | RNF-11; referenciado como RF-20 na matriz de rastreabilidade, nunca detalhado no corpo do documento — validado como fora de escopo, não como requisito |

## 3. Stack e justificativa

| Escolha | Por quê |
|---|---|
| Node.js + TypeScript | Já definido como restrição do projeto (seção 10.1) |
| Fastify/Express | Framework HTTP maduro, baixo overhead — compatível com RNF-01/07 (performance sob pico) |
| PostgreSQL | Consistência transacional forte, necessária para RNF-08 (zero duplicidade de assento) |
| Redis | Locks atômicos de curta duração (assentos), cache do catálogo TMDB, filas (BullMQ) e adapter do Socket.io para escalar WebSocket horizontalmente |
| Socket.io | Abstrai reconexão/rooms para chat e canal de assentos, exigidos por RF-05 e RF-10 |
| Prisma | Migrations versionadas, tipagem forte junto ao TypeScript |
| JWT | Autenticação stateless, compatível com múltiplas instâncias (RNF-07) |

## 4. Modelo de dados (visão lógica)

**Entidades principais**

- `User` (id, name, email, password_hash, created_at)
- `UserProfile` (user_id) + `FavoriteGenre` (user_id, genre) **[implementado, BE-08]** — `favorite_genres[]` como coluna de array escalar foi desenhado aqui, mas o ORM em uso (Prisma Next) rejeita colunas de lista escalar; normalizado em tabela própria (`user_id, genre`, unique composto), o que também deixa pronta a consulta "quem gosta do gênero X" que a personalização de feed (razão de ser do RF-02) vai precisar
- `Review` (id, user_id, movie_id, text, rating, has_spoiler, created_at) **[implementado, BE-15/BE-16/BE-17]** — schema completo criado na BE-15 (inclusive `has_spoiler`); a ofuscação de leitura veio na BE-16: `GET /reviews` mascara `text` (`null`) quando `hasSpoiler` é `true`, e `GET /reviews/:id/reveal` é a ação explícita que devolve o texto real. BE-17 adicionou `GET /reviews/:id/share`, que gera `{ url, title, text }` prontos para o share sheet nativo do client (Instagram/TikTok/etc. — o post em si é client-side); reaproveita a mesma ofuscação da BE-16 para não vazar spoiler pelo compartilhamento
- `ChatRoom` (id, type, created_at) **[implementado, BE-19]** — `type` é `String` (`"individual"`/`"group"`), não enum: o suporte a enum nesse Prisma Next contract-first é território não comprovado (mesma razão de `hasSpoiler` não ganhar um `Boolean`-like custom type), então a validação fica no DTO (`@IsIn`), igual ao padrão já usado para `rating` da `Review`
- `ChatRoomMember` (id, room_id, user_id, unique `[room_id, user_id]`) **[implementado, BE-19]**
- `Message` (id, room_id, sender_id, content, created_at) **[implementado, BE-19]**
- `Movie` (tmdb_id, title, synopsis, poster_url, cached_at)
- `CinemaPartner` (id, name, api_config) **[implementado, BE-13]**
- `Room`/`Auditorium` (id, partner_id, name) **[implementado, BE-13]** — sem `seat_layout`: a "planta" da sala é simplesmente o conjunto de linhas `Seat` daquela sala, não um campo de config à parte (nada consumia um formato de layout específico ainda)
- `Session` (id, movie_id, room_id, datetime, `price_cents`) **[implementado, BE-13]** — inteiro em centavos, não float, por causa de BE-27+ (pagamentos)
- `Seat` (id, room_id, code) **[implementado, BE-13]**
- `SeatLock` (session_id, seat_id, user_id, expires_at) — vive no **Redis**, TTL curto, nunca no Postgres. **[implementado, BE-23]** Chave `seat-lock:{sessionId}:{seatId}`, valor = `userId`, `EX` = `SEAT_LOCK_TTL_SECONDS` (default 300s). Lock de N assentos é um único script Lua (`SeatLockService`) — checa todas as chaves e só then seta todas se nenhuma existir, uma operação atômica de verdade (uma sequência de `SET NX` por chave deixaria uma janela de corrida entre o assento 1 e o assento 2). Liberação usa comparar-e-apagar (Lua também) — nunca apaga o lock de outro usuário
- `PartnerSeatState` (id, session_id, seat_id, status, sold_order_id, updated_at) **[implementado, BE-21]** — não estava no desenho original; existe porque o `MockPartnerGateway` precisa de um estado que sobreviva a múltiplas instâncias do backend (RNF-01/07), então não podia ser memória de processo. É deliberadamente uma tabela **separada** de `SeatLock`: simula o banco de dados do parceiro, uma "fonte da verdade" que o app não controla, então não pode ser a mesma estrutura que representa o lock do próprio app
- `Order` (id, user_id, session_id, status, total_amount, created_at) **[implementado, BE-24]** — `total_amount` é `totalAmountCents` (inteiro, centavos — mesma convenção do `Session.priceCents`); `status` começa e fica em `"pending"` até a BE-27+ existir (pagamento é o que faria a transição pra `"paid"`)
- `OrderItem` (order_id, seat_id, combo_item_id?) **[implementado, BE-24/26]** — uma linha por assento; "checkout individual" (1 assento) e "compra em grupo" (BE-25, N assentos) são a mesma tabela, a mesma forma de dado — a diferença é só quantos `OrderItem` uma `Order` tem. `combo_item_id` (BE-26) é opcional e por assento, não por pedido — pessoas diferentes num grupo podem escolher combos diferentes, ou nenhum
- `Ticket` (id, order_item_id, qr_code_payload, status: valid|used, used_at) **[implementado, BE-32/33]** — um por `OrderItem` (`@unique`, `onDelete: Cascade`); `qr_code_payload` também `@unique`, o índice direto que `POST /api/v1/tickets/validate` (RF-14/RNF-12, BE-33) usa — um `UPDATE` condicional (`WHERE qr_code_payload = ? AND status = 'valid'`) faz leitura+validação+marcação como "utilizado" numa única operação atômica (o lock de linha do Postgres serializa concorrência na mesma linha, sem precisar de script Lua como o lock de assento da BE-23). **Nota da BE-35**: esse `UPDATE` roda via SQL builder puro (`db.sql.public.ticket.update(...).build()` + `tx.execute`), não a API alto-nível do ORM — descoberto que essa última não é atômica de forma confiável sob carga concorrente mista (ver CLAUDE.md)
- `Payment` (id, order_id, method: pix|apple_pay|google_pay|card, provider_ref, status) **[implementado, BE-27/28/29 — `method: "pix"|"apple_pay"|"google_pay"|"card"`, todos aceitos]** — `method` é `String`, não enum, mesma cautela do resto do schema. Um `Payment` por `Order` (MVP simplificado)
- `ComboItem` (id, partner_id, name, price) **[implementado, BE-26]** — `price` é `priceCents` (inteiro, centavos — mesma convenção de `Session.priceCents`/`Order.totalAmountCents`). Menu por parceiro (`partnerId`), não global — um `comboItemId` de um parceiro nunca pode ser usado num pedido de outro parceiro, validado em `OrdersService`
- `PushToken` (id, user_id, token, platform) **[implementado, BE-34]** — `token @unique` (não `user_id`+`platform`): um token físico de dispositivo pode trocar de dono (logout/login de outro usuário no mesmo aparelho), então re-registrar um token existente transfere a linha pro novo `userId` em vez de duplicar

**Relações-chave**
- `Session → Room → CinemaPartner` (um único parceiro no MVP)
- `SeatLock` é efêmero e vira `Ticket` somente após pagamento confirmado
- `Ticket` tem payload de QR assinado (HMAC/JWT curto), não apenas um ID sequencial — evita ingresso forjado **[implementado, BE-32]** — JWT HS256 (`TicketsService`, `TICKET_QR_SECRET`), claim único `{orderItemId}`; o próprio JWT é o `qr_code_payload`, verificado antes de qualquer consulta ao banco

## 5. Fluxo crítico: compra em grupo sem duplicidade (RF-09, RF-10, RNF-08, CU-01)

1. Cliente busca sessão (`sessions`)
2. Cliente abre mapa de assentos → backend combina locks ativos (Redis) + status vindo do parceiro (mock) **[implementado, BE-22/23 — `SeatMapService.getMap`]**
3. Cliente seleciona N assentos → backend tenta lock atômico (`SET NX EX`) por assento; se qualquer um já está lockado/vendido, a seleção inteira falha com conflito **[implementado, BE-23 — `POST /sessions/:sessionId/seats/lock`, `SeatLockService.lockSeats`]**. Não é uma sequência de `SET NX EX` por assento (isso deixaria uma janela de corrida entre o assento 1 e o assento 2 de um mesmo pedido) — é um único script Lua que checa todas as N chaves e só então seta todas, uma operação atômica de verdade no Redis. Depois de garantir o lock local, sincroniza com o parceiro (`PartnerTicketingGateway.lockSeat`, BE-20/21); se o parceiro recusar qualquer assento do grupo, desfaz tudo (Redis + parceiro) — nunca fica um lock parcial
4. Lock confirmado → cria `Order` em status `pending` **[implementado, BE-24]** — `POST /api/v1/orders`, valida que o comprador realmente detém o lock Redis de cada assento pedido (`SeatLockService.getSeatIdsHeldBy`) antes de escrever qualquer coisa; `total_amount` calculado como `Session.priceCents × número de assentos`. O lock **não é liberado aqui** — continua sendo a proteção do assento durante toda a janela de "pedido pendente", exatamente como o passo 7 abaixo pressupõe
5. Cliente escolhe forma de pagamento → módulo `payments` **[Pix implementado, BE-27; Apple Pay/Google Pay implementado, BE-28; cartão via gateway implementado, BE-29 — todos os provedores mockados, sem contas reais disponíveis]**
6. Confirmação de pagamento (webhook do Pix, ou síncrona pra apple_pay/google_pay/card) → `PaymentsService.settlePaidOrder` **[implementado, BE-30 + BE-32]**:
   - confirma a venda junto ao mock do parceiro (operação idempotente) **[implementado, BE-30]** — `PartnerTicketingGateway.confirmSale(sessionId, seatId, orderId)`, por assento do pedido
   - converte lock em venda definitiva **[implementado, BE-30]** — `SeatLockService.releaseSeats`, chamado depois da confirmação acima; o lock Redis não precisa mais proteger o assento, então é liberado na hora em vez de esperar o TTL
   - gera `Ticket` + QR Code por assento **[implementado, BE-32]** — `TicketsService.generateForOrderItem(orderItemId)`, um por `OrderItem` do pedido
7. Falha/timeout de pagamento → lock expira pelo TTL, assento volta a ficar disponível automaticamente **[implementado, BE-23]** — `SEAT_LOCK_TTL_SECONDS` (default 300s), tratado pelo próprio Redis via `EX`, sem código adicional

Esse desenho é o que garante RNF-08 e é o ponto prioritário para testes de concorrência (TC-02 na matriz de rastreabilidade) — provado em `test/seat-lock-concurrency.e2e-spec.ts`: 20 tentativas concorrentes reais de lock no mesmo assento (Redis real, não mock), exatamente uma vence.

## 6. Tempo real (WebSocket)

- Namespace `/chat`: entrar/sair de sala, enviar/receber mensagem, indicador de "digitando" **[inferência — não citado nas entrevistas, comum em chats desse tipo]**. **[implementado, BE-19 — exceto o indicador de "digitando", que segue como inferência não implementada]** `ChatGateway` (`src/modules/chat/chat.gateway.ts`): evento `joinRoom` entra na room do Socket.io correspondente após checar membership; `sendMessage` persiste via `ChatService` e emite `newMessage` para a room inteira (`server.to(...)`), reaproveitando o adapter Redis da BE-18 para o broadcast cross-instância. Grupo e individual usam exatamente o mesmo pipeline de mensagens — a diferença entre os dois tipos é só na criação da sala (`POST /api/v1/chat/rooms`: individual faz get-or-create pelo par de usuários, grupo sempre cria uma sala nova)
- Namespace `/seats`: ao entrar em uma sessão, cliente recebe o estado atual do mapa e passa a receber `seat_locked` / `seat_released` / `seat_sold` em tempo real. **[implementado, BE-22]** Estado inicial é `GET /api/v1/sessions/:sessionId/seats/map` (REST, combina `Seat` + `PartnerTicketingGateway.getSeatMap`) — o WS (`SeatsGateway`) só entrega o snapshot inicial implicitamente via `joinSession` e depois os deltas (`lockSeat`/`releaseSeat` são eventos WS, broadcast pra sala inteira em sucesso; falha por disputa vai só pro socket que tentou, via `lockRejected`, não é broadcast — ninguém mais teve o próprio mapa mudado). `seat_sold` é disparado por `POST .../seats/:seatId/box-office-sale`, que simula uma venda feita fora do app (não existe checkout real ainda, BE-24/25) — é a própria forma de satisfazer o critério de aceite da task, que pede exatamente esse cenário. Sem conceito de "membership" de sala como o chat da BE-19 — qualquer usuário autenticado pode observar qualquer sessão, não há controle de acesso por sessão em nenhum outro lugar do app hoje
- Usar o adapter Redis do Socket.io para permitir múltiplas instâncias do backend (RNF-01, RNF-07) **[implementado, BE-18]** — `RedisIoAdapter` (`src/websocket/redis-io.adapter.ts`), plugado em `main.ts`; autenticação do handshake via o mesmo access token JWT do REST, verificada uma vez no nível do servidor Socket.io (não por gateway), então `/chat` (BE-19) e `/seats` (BE-22) herdam a proteção automaticamente. Ainda não existe nenhum gateway/namespace de domínio — isso é a base, não o chat em si

## 7. Integrações externas

**TMDB (RF-06, RT-02)**
Job periódico (BullMQ) sincroniza filmes em cartaz para uma tabela local (`Movie`), evitando depender da latência/disponibilidade do TMDB a cada requisição do usuário. Fallback: servir o último cache válido se o TMDB estiver fora.

**Sistema de bilheteria do parceiro (RF-10, RNF-02, RNF-10)**
Interface `PartnerTicketingGateway` com `getSeatMap`, `lockSeat`, `confirmSale`, `releaseSeat`. Implementação MVP: `MockPartnerGateway`. RNF-02 (homologação de segurança) é um processo formal com o parceiro, não uma tarefa de código — tratar como *gate* de go-live, não como task de implementação.

**[implementado, BE-20/BE-21]** `src/modules/partner-integration/partner-ticketing-gateway.interface.ts`. Métodos operam por assento individual (não em lote) — a atomicidade de "N assentos ou nenhum" (RNF-08) é garantida pelo lock Redis da BE-23, não por esta interface; o que ela protege é a venda pelo canal físico/outro canal do parceiro colidir com uma venda feita pelo app. `confirmSale` é contratualmente idempotente (webhook de pagamento pode chegar duplicado — explorado pela BE-30). `lockSeat`/`confirmSale` retornam `{success, reason?}` em vez de lançar exceção quando falham por disputa — perder uma corrida por um assento é resultado esperado, não erro. `MockPartnerGateway` (BE-21) é a única implementação até aqui, registrada em `PartnerIntegrationModule` sob o token `PARTNER_TICKETING_GATEWAY`; guarda seu estado em `PartnerSeatState` (Postgres), deliberadamente não em memória de processo, pra continuar correto com múltiplas instâncias. Não é concorrência-segura de propósito — duas chamadas simultâneas de `lockSeat` pro mesmo assento podem ambas ler "disponível" e ambas conseguirem travar; isso é aceitável porque a garantia real de RNF-08 é o lock Redis da BE-23, não esta mock. Consumido por `SeatMapService` (BE-22) e, desde a BE-30, por `PaymentsService.settlePaidOrder` (`confirmSale`)

**Pagamentos (RF-11, RF-12, RD-03)**
- Pix: provedor com suporte a Pix dinâmico (sandbox) **[implementado, BE-27]** — `src/modules/payments/`. Interface `PixProvider` (`createCharge(amountCents, referenceId)`) com `MockPixProvider` como única implementação, mesma situação de "sem provedor real disponível" da BE-20/21 — o "Copia e Cola" devolvido é deliberadamente falso (não tenta reproduzir o formato EMVCo/BR Code real). `POST /api/v1/orders/:orderId/payments` cria a cobrança (um pagamento por pedido, sem retry/expiração — simplificação de MVP); `POST /api/v1/payments/webhook/pix` (sem autenticação — é o provedor chamando, não um usuário) simula a confirmação, idempotente pra reentrega
- Apple Pay / Google Pay: tokenização acontece no client (Flutter); backend só recebe o token, nunca dado de cartão **[implementado, BE-28]** — mesma pasta `src/modules/payments/`. Interface `WalletProvider` (`charge(token, amountCents, referenceId)`) + `MockWalletProvider`, mesma situação de "sem provedor real disponível". `POST /api/v1/orders/:orderId/payments` aceita `{method:"apple_pay"|"google_pay", token}`; ao contrário do Pix, a confirmação é **síncrona** — a wallet já autorizou no client, então o backend grava `Payment`/`Order` como `paid` (ou `failed`) na própria chamada, sem esperar webhook nenhum. Não existe campo de cartão em nenhum método do DTO
- Cartão: gateway tipo Stripe/Pagar.me **[implementado, BE-29]** — mesma pasta `src/modules/payments/`. Interface `CardGatewayProvider` + `MockCardGatewayProvider`; sem conta real de gateway disponível (confirmado pelo usuário, 2026-08-29), simulação interna. `CardGatewayProvider` e `WalletProvider` (BE-28) são ambos só `type` aliases de um contrato compartilhado, `TokenChargeProvider` (`token-charge-provider.interface.ts`) — mesmo formato de confirmação síncrona por token pros dois, cada um com seu próprio símbolo de DI e mock, plugável por um gateway real depois sem tocar em `PaymentsService`. `POST /api/v1/orders/:orderId/payments` aceita `{method:"card", token}`; qualquer campo de cartão (número, validade, CVV) que o corpo tente incluir é rejeitado com `400` pelo `ValidationPipe` global (`forbidNonWhitelisted`), não apenas ignorado
- Confirmação de pagamento → conversão em venda definitiva + geração de ingresso (RF-11, RF-12, RF-13): **[implementado, BE-30 + BE-32]** — `PaymentsService.settlePaidOrder(orderId)`, chamado assim que QUALQUER método chega a `"paid"` (webhook assíncrono do Pix, ou o fim síncrono de `create` pra apple_pay/google_pay/card). Confirma a venda com o parceiro por assento (`PartnerTicketingGateway.confirmSale`, idempotente), libera o lock Redis (`SeatLockService.releaseSeats`) e gera um `Ticket` assinado por `OrderItem` (`TicketsService.generateForOrderItem`) — as três partes do passo 6 (§ 5) numa só chamada, disparadas por todo método de pagamento, não só Pix
- RD-03: **[inferência]** conformidade regulatória do Pix delegada ao provedor homologado, não implementada internamente — **[bloqueada, BE-31]**: não é uma verificação que dê pra fazer contra `MockPixProvider`; depende do negócio escolher e contratar um provedor Pix real primeiro. Ver a nota da BE-31 em BACKLOG_BACKEND.md

**Notificações push (RF-17)**
FCM (cobre Android e iOS), compatível nativamente com Flutter. Job agendado para lembrete de sessão X horas antes.

- Cadastro de push token **[implementado, BE-34]** — `src/modules/notifications/`. `POST /api/v1/push-tokens` (`{token, platform:"ios"|"android"}`) faz achar-por-token-e-criar-ou-atualizar (não `.upsert()` — mesma ressalva do `CatalogSyncService`, essa API só concilia pela PK). Um `PushToken` por dispositivo, nunca duplicado mesmo que o dono do token mude
- Job de lembrete de sessão **[implementado, BE-35]** — `src/modules/notifications/session-reminder.*`, mesmo padrão Scheduler/Processor/Service da sincronização de catálogo (BE-06). `SessionReminderService.sendDueReminders` roda a cada `SESSION_REMINDER_INTERVAL_MS` (default 15 min), notifica uma vez por (usuário, sessão) — não por assento — para sessões dentro de `SESSION_REMINDER_HOURS_BEFORE` (default 24h) com pedido `paid`; `SessionReminder` (unique por par) evita reenvio a cada tick. `PushSender`/`MockPushSender` simula o FCM (sem projeto Firebase real disponível)
- Push de promoções/novidades **[implementado, BE-36]** — `src/modules/notifications/promotion-push.*`. `POST /api/v1/notifications/broadcast` (`{title, body}`) dispara sob demanda pra **todo** `PushToken` cadastrado (sem opt-in/segmentação nesta versão), reaproveitando o mesmo `PushSender`/`MockPushSender` do lembrete de sessão (BE-35)

## 8. Segurança e privacidade

- JWT com refresh token + rate limiting nos endpoints de auth
- RNF-11: ~~endpoints do painel B2B retornam apenas dados agregados (`COUNT`, `AVG`, `SUM`), nunca registros individuais~~ — **fora de escopo** (não haverá painel B2B, confirmado pelo usuário 2026-08-29; ver Fase 8 em BACKLOG_BACKEND.md)
- RNF-02: checklist de segurança da API de integração com o parceiro antes do go-live
- QR Code com payload assinado, para não ser forjável a partir de um ID sequencial

## 9. RNF → decisão técnica

| RNF | Decisão técnica |
|---|---|
| RNF-01 / RNF-07 | Node stateless + Redis compartilhado → escala horizontal; teste de carga com k6/Artillery |
| RNF-04 | Health checks + monitoramento **[inferência — ferramenta não especificada pelos stakeholders]** |
| RNF-06 | Backend minimiza payload (paginação, gzip, imagens servidas via URL do TMDB, não via proxy) |
| RNF-08 | Lock atômico Redis + confirmação transacional (seção 5) |
| RNF-09 | Não impacta o backend diretamente (gratuidade é sobre distribuição do app) |
| RNF-11 | ~~Camada de agregação isolada para o painel B2B~~ — **fora de escopo**, confirmado pelo usuário (2026-08-29) |
| RNF-12 | Endpoint de validação de QR dedicado, sem joins pesados, índice direto por código do ticket **[implementado, BE-33]** — `POST /api/v1/tickets/validate`; assinatura verificada antes de qualquer query, depois um único `UPDATE` condicional indexado por `qrCodePayload @unique`, sem select prévio nem join. Medido ao vivo: ~5-10ms, bem abaixo do limite |

## 10. Pontos a validar antes de virar backlog fechado

A Matriz de Rastreabilidade (seção 14) e a MoSCoW (seção 11) do documento original citam **RF-18, RF-19, RF-20, RF-21, RN-02, RN-06, RT-04 e CU-03** (painel B2B/backoffice, push segmentado por região), mas essas seções não os detalham no corpo do documento (seções 5, 6 e 13). Este documento assumiu um módulo `analytics`/B2B como inferência razoável para preencher essa lacuna — **resolvido**: o usuário confirmou (2026-08-29) que não haverá painel B2B, e que o push segmentado por região (CU-03, bundlado na mesma inferência) também não faz parte do escopo real. O módulo `analytics` e a Fase 8 inteira do backlog (BE-37/38/39) ficam marcados como fora de escopo, não como pendência — ver BACKLOG_BACKEND.md.
