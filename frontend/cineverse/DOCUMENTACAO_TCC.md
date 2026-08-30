# CineVerse — Documentação Técnica

> Documentação de referência — base para o TCC. Reúne arquitetura, decisões técnicas,
> modelagem de dados e o estado real de implementação dos dois repositórios do projeto —
> `backend` (NestJS) e `frontend/cineverse` (Flutter) — para servir de base de consulta ao
> escrever o TCC. Não é texto acadêmico pronto: não tem citação bibliográfica e não deve ser
> colado direto no trabalho (ver seção 11).

**Em números:** 20 modelos de dados · 35 rotas REST + 2 namespaces WebSocket · ~270 casos de
teste automatizados · 36/48 tarefas concluídas no backend · 2/56 marcadas no backlog do
frontend (ver nota na seção 5 sobre esse número).

---

## Sumário

1. [Visão geral](#1-visão-geral)
2. [Objetivos](#2-objetivos)
3. [Arquitetura do sistema](#3-arquitetura-do-sistema)
4. [Modelagem de dados](#4-modelagem-de-dados)
5. [Requisitos e rastreabilidade](#5-requisitos-e-rastreabilidade)
6. [Decisões arquiteturais](#6-decisões-arquiteturais-e-justificativas)
7. [Desafios técnicos resolvidos](#7-desafios-técnicos-resolvidos)
8. [Estratégia de testes](#8-estratégia-de-testes)
9. [Limitações e trabalhos futuros](#9-limitações-conhecidas-e-trabalhos-futuros)
10. [Stack tecnológico](#10-stack-tecnológico)
11. [Como usar isto no TCC](#11-como-usar-isto-no-tcc)

---

## 1. Visão geral

O CineVerse nasce da junção de dois problemas que hoje são resolvidos por apps separados:
descobrir o que assistir (rede social de crítica/resenha, ao estilo Letterboxd) e comprar o
ingresso perto de casa (bilheteria de cinema). A proposta do projeto é unir os dois num único
fluxo — o usuário lê uma resenha, decide ver o filme, e a partir da mesma tela encontra o
cinema parceiro mais próximo, escolhe a poltrona e paga, sem trocar de aplicativo.

O sistema tem três eixos funcionais, cada um com uma exigência técnica diferente:

- **Social** — Feed de resenhas com nota, texto e controle de spoiler (o texto só é liberado
  sob ação explícita do leitor), chat em tempo real entre cinéfilos e compartilhamento via
  share sheet nativa.
- **Descoberta** — Catálogo sincronizado periodicamente com o TMDB (título, sinopse, pôster,
  categoria por data de lançamento) e busca hiperlocal do cinema parceiro mais próximo por
  coordenadas geográficas.
- **Compra** — Mapa de assentos com estado sincronizado em tempo real entre todos os
  compradores da mesma sessão, reserva temporária (lock) antes do pagamento, checkout
  individual ou em grupo, e emissão de ingresso com QR assinado.

**O que muda entre eles:** Social e Descoberta são consumo de dado relativamente estável.
Compra é o único fluxo com **estado compartilhado entre usuários diferentes mudando enquanto
a tela está aberta** — é isso que justifica boa parte das decisões técnicas das seções
seguintes (Redis, WebSocket, lock atômico).

O projeto é dividido em dois repositórios com convenções próprias: um backend NestJS já
considerado "pronto e funcionando" que o frontend consome como contrato fechado, e um cliente
Flutter (Android/iOS) construído depois, sobre a API real — nunca o inverso. Essa ordem
(backend primeiro, contrato como fonte da verdade) é decisão deliberada e aparece de novo na
seção 6.

---

## 2. Objetivos

### Objetivo geral

Projetar e implementar uma plataforma cliente-servidor que integre descoberta social de
filmes e compra de ingresso hiperlocalizada num único aplicativo móvel, com consistência
garantida no servidor para operações concorrentes (reserva de assento) e sincronização em
tempo real entre clientes.

### Objetivos específicos

- Implementar autenticação stateless (JWT) com cadastro, login e perfil de preferências
  (gêneros favoritos).
- Sincronizar periodicamente um catálogo de filmes externo (TMDB) com cache local, tolerando
  indisponibilidade da fonte.
- Implementar busca hiperlocal do cinema parceiro mais próximo por distância geográfica.
- Garantir, sob concorrência real, que dois usuários nunca reservem o mesmo assento —
  validado por teste automatizado de concorrência, não apenas por inspeção de código.
- Sincronizar o mapa de assentos entre todos os clientes conectados à mesma sessão via
  WebSocket.
- Implementar um fluxo de resenhas com ofuscação de spoiler no servidor (o texto nunca
  trafega para quem não pediu para ver).
- Implementar chat em tempo real entre usuários, com histórico persistido.
- Emitir ingresso com QR assinado criptograficamente, validável por um segundo dispositivo (o
  do cinema) sem consulta adicional além da verificação de assinatura.
- Documentar, com transparência, os limites reais entre o que a API oferece hoje e o que o
  cliente precisa — tratando a integração como parte do objeto de estudo, não como detalhe de
  implementação.

---

## 3. Arquitetura do sistema

O sistema segue um modelo cliente-servidor clássico, com o backend como única fonte da
verdade — o cliente nunca decide sozinho se um assento está livre, se um pagamento foi
aprovado ou se um ingresso é válido; ele sempre pergunta ao servidor.

### Visão macro

```
                 Cliente Flutter (Android / iOS)
                              │
        REST (dio) + WebSocket (socket_io_client)
              JWT no header / no handshake
                              │
                              ▼
      API NestJS · REST + Gateways Socket.io (/chat, /seats)
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
     PostgreSQL             Redis           Serviços externos
   (via Prisma —      (lock de assento,    (TMDB, gateway de
 dados transacionais)   cache TMDB, filas   pagamento e bilheteria
                        BullMQ, adapter      — mockados no MVP —
                          Socket.io)          e push mockado)
```

### Backend — módulos e requisitos atendidos

| Módulo | Responsabilidade | Requisito |
|---|---|---|
| `auth` | Cadastro, login, emissão de JWT | RF-01 |
| `users` | Perfil e preferências de gênero | RF-02 |
| `feed` | Resenhas, ofuscação de spoiler, compartilhamento | RF-03, RF-04, RF-16 |
| `chat` | Mensagens em tempo real, histórico | RF-05 |
| `catalog` | Sincronização e cache do catálogo TMDB | RF-06 |
| `sessions` | Sessões do cinema parceiro, busca hiperlocal | RF-07 |
| `seats` | Mapa de assentos, lock, sincronização com o parceiro | RF-10, RNF-08 |
| `orders` | Checkout individual/grupo, combos | RF-08, RF-09, RF-15 |
| `payments` | Pix, Apple Pay, Google Pay, cartão (mockados) | RF-11, RF-12 |
| `tickets` | Geração e validação de QR | RF-13, RF-14, RNF-12 |
| `notifications` | Push (registro real, entrega mockada) | RF-17 |
| `partner-integration` | Abstração do ERP/bilheteria do parceiro | RNF-02, RNF-10 |

### Frontend — camadas

O cliente segue arquitetura em camadas *feature-first*, sem camada de *usecase* — decisão
registrada explicitamente (seção 6) porque a regra de verdade do domínio (atomicidade da
reserva, assinatura do ingresso) mora no servidor; replicá-la no cliente seria duplicá-la no
lugar errado.

```
Page / Widget  →  Bloc  →  Repository (interface)  →  Api / Socket  →  backend
```

Todo Bloc segue um único formato de estado (`status` + `Equatable` + `copyWith`), com exceção
de `Failure`, que usa `sealed class` para *pattern matching* exaustivo — a única estrutura de
dado do domínio que precisa dessa garantia em tempo de compilação. O motivo de não usar
estados `sealed` separados por tela é concreto: o mapa de assentos recebe atualização por
WebSocket enquanto a tela já está aberta, e um modelo `Loading`/`Loaded` descartaria os dados
já carregados a cada evento, piscando a tela.

13 Blocs/Cubits ao todo, um por tela (nunca *singleton*), com a única exceção sendo o
`AuthBloc` — sessão global instanciada uma vez na raiz do app.

### Tempo real

Dois namespaces Socket.io, cada um resolvendo um problema de consistência diferente:

- **`/seats`** — Sincroniza o mapa de assentos entre todos os clientes olhando a mesma
  sessão. Eventos `seat_locked`/`seat_released`/`seat_sold` fazem broadcast para a sala;
  `lockRejected` só volta para quem pediu. Latência medida em teste: **~28ms**.
- **`/chat`** — Mensagens via `sendMessage` → broadcast `newMessage` para a sala (o remetente
  também recebe a própria mensagem de volta — o cliente precisa deduplicar). Latência medida
  em teste: **~17ms**.

Ambos os gateways rodam sobre um `RedisIoAdapter`, que existe especificamente para permitir
múltiplas instâncias do backend atrás de um balanceador — sem ele, dois usuários conectados a
instâncias diferentes do servidor nunca trocariam eventos entre si.

---

## 4. Modelagem de dados

20 modelos no schema Prisma (`contract.prisma`), cobrindo identidade, catálogo, o par
sessão/assento, o fluxo de compra e o par resenha/chat. Os agrupamentos abaixo seguem a razão
de existir de cada tabela, não a ordem alfabética.

| Domínio | Modelos | Observação de projeto |
|---|---|---|
| Identidade | `User`, `UserProfile`, `FavoriteGenre` | `FavoriteGenre` é uma linha por gênero (não uma coluna de lista) porque o ORM em uso rejeita colunas de lista escalar. |
| Catálogo | `Movie` | Populado só pelo job de sincronização — nunca escrito por requisição de usuário, para a latência do TMDB nunca bloquear uma tela. |
| Cinema e sessão | `CinemaPartner`, `Room`, `Seat`, `Session` | `CinemaPartner` guarda latitude/longitude para a busca hiperlocal (RF-07) — campo fora do desenho original, adicionado porque o requisito não existe sem ele. |
| Social | `Review`, `ChatRoom`, `ChatRoomMember`, `Message` | `hasSpoiler` existe desde o início mesmo antes de ser aplicado na leitura — evita uma segunda migração na mesma tabela. |
| Compra | `PartnerSeatState`, `Order`, `OrderItem`, `ComboItem`, `Payment`, `Ticket` | `PartnerSeatState` é deliberadamente uma tabela separada do lock em Redis: ela simula o banco do parceiro (bilheteria real), não pode ser a mesma estrutura que representa a reserva do próprio app. |
| Notificação | `PushToken`, `SessionReminder` | `SessionReminder` é uma linha por (usuário, sessão) já enviada — é o registro que impede notificar a mesma pessoa duas vezes num job recorrente. |

> **Decisão de projeto — enum vira String.** Campos que soariam como `enum` em outro stack
> (`ChatRoom.type`, `PartnerSeatState.status`, `Payment.method`, `Ticket.status`) são
> `String` simples, validados na camada de DTO. Motivo documentado: o suporte a enum nesse
> ORM contract-first era, no momento da decisão, "território não comprovado" — trade-off
> deliberado de menos garantia de tipo por mais previsibilidade de build.

> **O lock de assento não é uma tabela.** A reserva temporária de um assento (RNF-08) vive só
> em Redis, chave `seat-lock:{sessionId}:{seatId}`, TTL configurável (padrão 300s), aplicada
> por um único script Lua atômico — não uma sequência de `GET` + `SET`, que teria uma janela
> de corrida entre os dois comandos. É essa escolha, testada sob concorrência real, que
> sustenta a garantia de "zero assento duplicado" (seção 7).

---

## 5. Requisitos e rastreabilidade

Cada requisito funcional tem uma tarefa de backend e uma de frontend associadas nos
respectivos backlogs (`BE-XX` / `FE-XX`), o que permite rastrear, requisito a requisito, o
que está implementado, o que está bloqueado e por quê.

| Requisito | Tarefas (frontend) | Situação |
|---|---|---|
| RF-01 — Cadastro e autenticação | FE-09 – FE-12 | ✅ completo |
| RF-02 — Perfil e preferências | FE-13 | ✅ completo |
| RF-03 — Publicação de resenhas | FE-19, FE-22 | ✅ completo (sem nome do autor — atrito 3) |
| RF-04 — Spoiler | FE-20, FE-21 | ✅ completo |
| RF-05 — Chat em tempo real | FE-24 – FE-26 | ✅ completo |
| RF-06 — Catálogo | FE-14 – FE-16 | ✅ completo |
| RF-07 — Busca hiperlocal | FE-17, FE-18 | ✅ completo |
| RF-08 — Checkout em até 3 passos | FE-30, FE-34, FE-39 | ✅ completo |
| RF-09 — Compra em grupo | FE-30, FE-33, FE-34 | ✅ completo |
| RF-10 / RD-02 — Mapa em tempo real | FE-27 – FE-29 | ✅ completo |
| RF-11 / RF-12 — Pagamentos | FE-35 – FE-38 | ✅ completo (provedores simulados) |
| RF-13 — Ingresso com QR | FE-40 | 🔴 bloqueado |
| RF-14 / RNF-12 — Validação de ingresso | FE-41 | ✅ completo |
| RF-15 — Combos | FE-33 | ✅ completo |
| RF-16 — Compartilhamento | FE-23 | ✅ completo |
| RF-17 — Notificações | FE-42, FE-43 | 🟡 registro ok, entrega não verificável |

### Progresso agregado dos backlogs

| Repositório | Tarefas | Concluídas | Fora de escopo | Pendentes |
|---|---:|---:|---:|---:|
| Backend (BE-01 a BE-48) | 48 | 36 | 3 | 9 |
| Frontend (FE-01 a FE-56) | 56 | 2* | 0 | 54 |

\* O backlog de frontend rastreia FE-13 e FE-14 como as únicas explicitamente marcadas no
arquivo de controle na data da última atualização registrada — o volume real de telas
construídas na sessão de desenvolvimento é maior (catálogo, sessões, assentos, checkout,
perfil, resenhas, navegação) do que o checklist reflete; use a seção 3 e o histórico de
commits, não só o checklist, para descrever cobertura no TCC.

Fora de escopo, confirmado com o cliente do projeto: painel B2B/analytics para o cinema
parceiro, integração real com múltiplas redes de cinema, catraca 100% offline,
fidelidade/gamificação e recomendação por IA.

---

## 6. Decisões arquiteturais e justificativas

A tabela reúne as decisões mais citáveis num TCC — cada uma tem uma alternativa descartada e
um motivo registrado no momento em que foi tomada, não reconstruído depois.

| Decisão | Alternativa descartada | Motivo registrado |
|---|---|---|
| NestJS | Express/Fastify puro | Estrutura modular e DI nativos reduzem código de encanamento repetido nos 12 módulos. |
| PostgreSQL | MongoDB | Consistência transacional forte — necessária para "zero assento duplicado" (RNF-08). |
| Redis para o lock | Lock só no Postgres | Operação atômica de baixa latência com expiração automática (TTL) sem job de limpeza. |
| Socket.io | WebSocket puro | Abstrai reconexão e salas (rooms), exigidos por chat e mapa de assentos. |
| JWT stateless | Sessão em servidor | Compatível com múltiplas instâncias sem sessão compartilhada (RNF-07). |
| flutter_bloc | Provider/Riverpod/GetX | Requisito do trabalho — decisão não estava em aberto. |
| Sem camada de *usecase* no cliente | Clean Architecture com usecases | A regra de negócio real mora no servidor; replicá-la no cliente duplicaria a fonte da verdade. |
| Estado único por Bloc (`status`) | Estados `sealed` por tela | Atualização por WebSocket no meio da tela exige preservar dado já carregado, não descartar. |
| Entrada da compra sempre por `/nearby` | Entrar direto pelo catálogo | `partnerId` só existe na resposta de `/sessions/nearby` — nenhuma outra rota devolve esse dado. |
| Reserva em grupo via REST, não WebSocket | Lock via evento de socket | Atomicidade de escrita é mais fácil de garantir numa requisição REST idempotente do que num evento assíncrono. |
| Sem painel administrativo no app | Tela de cadastro de cinema no próprio app | O backend não tem papel de administrador — qualquer JWT válido cadastra parceiro; expor isso no app do usuário final seria uma falha de escopo, não um recurso. |
| Só mobile (Android/iOS), sem Flutter Web | Alvo também web | O backend não habilita CORS — bloqueio técnico verificável, não preferência de equipe. |

---

## 7. Desafios técnicos resolvidos

Esta seção é provavelmente a mais valiosa para o capítulo de "resultados"/"discussão" do TCC:
são problemas reais, encontrados durante a implementação (não hipotéticos), com causa raiz
identificada e correção verificada por teste.

### Concorrência na reserva de assento

> **Prova por teste, não por inspeção.** O requisito "zero assento vendido duas vezes"
> (RNF-08) foi validado por um teste e2e que dispara **20 tentativas de lock concorrentes
> reais** sobre o mesmo assento — o resultado esperado (e obtido) é exatamente uma
> vencedora. Isso existe porque testar concorrência por leitura de código é insuficiente: a
> garantia só é real se sobrevive à execução simultânea de fato.

### Duas armadilhas do ORM encontradas em produção (não no papel)

**`.where(predicate).delete()` apaga só uma linha.** Mesmo quando o predicado casa com várias
linhas, o ORM em uso (Prisma Next, ainda em RC) deleta apenas a primeira — verificado
empiricamente contra um Postgres real (3 linhas casavam, 2 sobreviveram).
*Correção:* qualquer exclusão múltipla passou a usar o SQL builder de baixo nível da mesma
biblioteca, não o atalho de alto nível.

**`.where(predicate).update(...)` não é atômico sob concorrência real.** Descoberto durante a
tarefa de validação de ingresso (BE-35): com um processador de fila (BullMQ) rodando em
paralelo, 2 de 20 chamadas concorrentes de validação "venceram" quando deveria vencer
exatamente 1. A causa raiz específica no driver não foi identificada — só o efeito, de forma
reprodutível.
*Correção:* o "verificar-e-então-atualizar" condicional passou a usar o SQL builder cru
dentro de uma transação explícita. Regra registrada para qualquer código futuro: nunca usar o
atalho de alto nível quando a atomicidade da corrida é a garantia que o código precisa
entregar.

### Segurança

- **Segredos de access/refresh token são diferentes** — vazar um não permite forjar o outro.
- **Timing-safe login:** o servidor sempre roda `bcrypt.compare`, mesmo quando o e-mail não
  existe (contra um hash fixo), para não vazar por tempo de resposta se a conta existe ou
  não.
- **Ingresso não é um número sequencial:** o payload do QR é um JWT assinado (HMAC HS256) —
  um ingresso não pode ser forjado incrementando um id, só reproduzindo uma assinatura
  válida.
- **Toda rota é protegida por padrão** — o guard de autenticação é global; uma rota pública
  precisa optar explicitamente por sair da proteção, não o contrário (menor chance de
  esquecer de proteger algo novo).

### Bugs de infraestrutura em tempo real (WebSocket)

- Um middleware de autenticação de socket registrado da forma ingênua só se aplica ao
  namespace padrão (`/`) — namespaces nomeados (`/chat`, `/seats`) o ignoram silenciosamente.
  Corrigido escutando o evento de criação de namespace.
- O adapter Redis do Socket.io fechava a conexão sem verificar se ela já estava fechada,
  derrubando o processo na segunda instância do gateway. Corrigido com uma flag de estado
  explícita.

---

## 8. Estratégia de testes

O frontend declara explicitamente, na própria documentação de arquitetura, que sua meta é
*"espelhar a disciplina do backend"*. Os números abaixo são contagem direta nos dois
repositórios, não estimativa.

| Camada | Ferramenta | Casos | Cobre |
|---|---|---:|---|
| Backend — unitário | Jest | ~188 | Services, guards, gateways, mapeamento de erro |
| Backend — ponta a ponta | Jest + Supertest | 11 | Concorrência de lock, concorrência de validação de ingresso, compra em grupo, WebSocket, fluxo de app |
| Frontend — Bloc | bloc_test + mocktail | ~54 | Todo Bloc/Cubit do app — estado emitido por evento |
| Frontend — unitário puro | flutter_test | ~26 | Agrupamento de assento por fileira, formatação de moeda/data, mapeamento de falha |

O teste mais citável para uma banca é o de concorrência (seção 7): ele não verifica um
comportamento determinístico isolado, verifica uma **propriedade sob execução concorrente
real** — categoria de teste bem mais rara de ver implementada em projetos acadêmicos, e um
bom ponto de discussão metodológica no TCC (por que teste de unidade não seria suficiente
aqui).

---

## 9. Limitações conhecidas e trabalhos futuros

Esta é, deliberadamente, a seção mais honesta do projeto — e a mais útil para um capítulo de
"limitações e trabalhos futuros" de TCC. Cada item é uma lacuna real da API descoberta
durante a integração, com a decisão tomada e o que destravaria a lacuna.

1. **Não existe rota que devolva um ingresso comprado** 🔴 bloqueado
   O servidor gera o `Ticket` (com QR assinado) ao confirmar o pagamento, mas nenhuma rota o
   expõe de volta — `tickets` só tem `POST /tickets/validate`.
   *Decisão:* implementar tudo até a confirmação da compra; a tela de ingresso mostra um
   estado explícito de "indisponível nesta versão", nunca um QR fabricado no cliente.
   *Destrava com:* uma rota nova, `GET /orders/:orderId/tickets` — mudança pequena no
   backend.

2. **Não existe busca de usuário**
   Criar uma sala de chat exige `memberIds` numéricos, mas não há endpoint de
   busca/listagem de usuários.
   *Decisão:* o chat só pode ser iniciado a partir do autor de uma resenha do feed (única
   fonte de `userId` alheio na API inteira) — isso define, por limitação real e não por
   design, onde a tela de "nova conversa" pode existir.

3. **Resenha não traz nome do autor nem título do filme**
   `GET /reviews` devolve só `userId` e `movieId`.
   *Decisão:* o cliente cruza `movieId` com o catálogo já carregado (junção no repositório,
   não na tela); o nome do autor não tem como ser resolvido — a tela mostra "Cinéfilo #42" e
   assume isso como limitação declarada, não como bug.

4. **`partnerId` só existe via `/sessions/nearby`**
   Não existe `GET /rooms/:id` nem qualquer outra rota que devolva o id do parceiro a partir
   de uma sessão isolada.
   *Decisão:* a navegação de compra é desenhada para sempre entrar por `/nearby`, carregando
   o `partnerId` no estado até o checkout precisar dele.

5. **Confirmação de Pix nunca chega ao app**
   O webhook do provedor de pagamento fala só com o backend, nunca com o cliente.
   *Decisão:* o app faz *polling* em `GET /orders/:orderId/payments` a cada poucos segundos,
   com o mesmo teto de tempo do lock do assento (5 minutos) — depois disso, expira do mesmo
   jeito que o assento expiraria.

6. **Push nunca é entregue de verdade**
   O emissor de push do backend só escreve em log (mock), por decisão de projeto — não há
   projeto Firebase real configurado.
   *Decisão:* o registro do token (`POST /push-tokens`) é implementado de verdade; a entrega
   é declarada como não verificável nesta versão, não simulada no cliente.

7. **Não existe renovação de sessão**
   Não há endpoint de *refresh token*; a sessão dura os 15 minutos do access token.
   *Decisão:* ao expirar, o app encerra a sessão e pede login de novo — comportamento
   correto dado o contrato atual, mas seria a primeira melhoria de UX a fazer se a API
   ganhasse a rota.

8. **Cadastro de cinema/sala/sessão é aberto a qualquer conta**
   Os endpoints administrativos (`POST /partners`, `/rooms`, `/seats`, `/sessions`,
   `/combos`) só exigem um JWT válido — não existe papel de administrador no backend, por
   simplificação de MVP.
   *Decisão:* nenhuma tela de cadastro administrativo é exposta no app do usuário final; a
   massa de dados é criada por um script HTTP versionado fora do app.

### Fora de escopo, por confirmação explícita do cliente do projeto

Painel B2B/analytics para o cinema parceiro, integração real com múltiplas redes de cinema,
catraca 100% offline, fidelidade/gamificação/recomendação por IA e Flutter Web (bloqueado
pela ausência de CORS no backend, não por preferência).

---

## 10. Stack tecnológico

### Backend

- `@nestjs/core` ^11.0.1 — framework
- `@prisma/orm-postgres` ^8.0.0-rc.8 — ORM contract-first
- `socket.io` ^4.8.3 + `@socket.io/redis-adapter` ^8.3.0
- `@nestjs/bullmq` + `bullmq` ^6.3.2 — filas
- `ioredis` ^6.0.0
- `@nestjs/jwt` ^12.0.1, `bcryptjs` ^3.0.3
- `class-validator` / `class-transformer` — DTOs
- `nestjs-pino` + `pino` — log estruturado
- `jest` ^30 + `supertest` ^7 — testes

### Frontend

- `flutter_bloc` ^9.0.0 + `equatable` ^2.0.5
- `dio` ^5.7.0 — HTTP
- `socket_io_client` ^3.0.2 — WebSocket
- `go_router` ^14.6.2 — navegação declarativa
- `flutter_secure_storage` ^9.2.2 — token em Keychain/Keystore
- `get_it` ^8.0.3 — injeção de dependência
- `qr_flutter` ^4.1.0 + `mobile_scanner` ^6.0.6
- `geolocator` ^13.0.2 + `permission_handler` ^11.3.1
- `cached_network_image` ^3.4.1, `flutter_svg` ^2.0.10
- `bloc_test` ^10.0.0 + `mocktail` ^1.0.4 — testes

Persistência: **PostgreSQL** (dados transacionais) + **Redis** (lock de assento, cache do
TMDB, backing das filas BullMQ e adapter do Socket.io). Linguagem: TypeScript no backend,
Dart 3 no frontend (com `sealed class` e *pattern matching* usados de propósito no
tratamento de falhas).

---

## 11. Como usar isto no TCC

Este documento é material de consulta, não texto acadêmico pronto — ele não tem citação
bibliográfica e não deve ser colado direto no TCC. Um mapeamento sugerido para os capítulos
usuais de um TCC de engenharia/computação:

| Capítulo típico | Seções deste documento |
|---|---|
| Introdução / Justificativa | 1, 2 |
| Fundamentação teórica | Ver nota abaixo — precisa de citação própria |
| Materiais e métodos / Arquitetura da solução | 3, 4, 6, 10 |
| Desenvolvimento / Implementação | 5, 7 |
| Resultados e validação | 7 (concorrência), 8 |
| Discussão / Limitações | 9 |
| Conclusão e trabalhos futuros | 9 (subseção de trabalhos futuros) |

> **Fundamentação teórica ainda precisa de referência formal.** Os conceitos abaixo aparecem
> no projeto e normalmente pedem citação de fonte primária num TCC — este documento descreve
> *como* foram aplicados, não substitui a leitura/citação da fonte: padrão BLoC (documentação
> oficial do Flutter), arquitetura em camadas e o argumento contra camada de *usecase*
> redundante (Clean Architecture, Robert C. Martin), autenticação stateless com JWT (RFC
> 7519), consistência transacional e isolamento em bancos relacionais (ACID), padrões de
> concorrência com lock distribuído (Redis / algoritmo Redlock), e comunicação bidirecional
> em tempo real sobre WebSocket (especificação Socket.io).

---

*Gerado a partir da leitura direta dos repositórios `backend` e `frontend/cineverse`
(CLAUDE.md, ARQUITETURA_BACKEND.md, ARQUITETURA_FRONTEND.md, BACKLOG_BACKEND.md,
BACKLOG_FRONTEND.md, `contract.prisma`, `package.json`, `pubspec.yaml` e contagem direta de
arquivos/testes) — não contém dado inventado; onde a fonte declarava incerteza (ex.:
contagem exata de testes), o número aproximado está marcado como tal.*
