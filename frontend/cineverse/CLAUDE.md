# CineVerse — Frontend (Flutter)

> Contexto de projeto lido automaticamente pelo Claude Code ao abrir esta pasta. Mantenha atualizado conforme o projeto evolui.

## O que é o CineVerse

App B2C que une rede social de cinéfilos (feed de resenhas com controle de spoiler, chat em tempo real) e compra de ingressos hiperlocalizada num cinema parceiro. Este repositório é o **cliente Flutter**. O backend é um projeto separado, **já implementado e funcionando**, em `../backend`.

Documentos de referência (mesma pasta):
- `ARQUITETURA_FRONTEND.md` — camadas, BLoC, navegação, contrato de integração com a API, atritos conhecidos
- `BACKLOG_FRONTEND.md` — tasks `FE-XX`, cada uma rastreada ao RF/RNF de origem **e ao endpoint de backend que consome**

Documentos do backend que valem leitura antes de qualquer integração:
- `../backend/docs/DOSSIE_TECNICO_CODIGO.md` — o que a API faz, classe por classe
- `../backend/CLAUDE.md` — convenções do servidor
- `../backend/src/prisma/contract.prisma` — modelo de dados real (fonte da verdade das entidades)

## Regra número um deste projeto

**O frontend consome exatamente o que o backend oferece hoje — nada mais.** Não inventar endpoint, campo de resposta ou comportamento que não exista em `../backend/src`. Quando faltar algo (e falta — ver `ARQUITETURA_FRONTEND.md` § "Atritos conhecidos"), a saída é uma de três, nesta ordem de preferência:

1. Resolver no cliente com o que a API já devolve (ex.: cruzar `movieId` da resenha com o catálogo já carregado).
2. Desenhar a navegação para que o dado necessário já esteja em mãos (ex.: entrar no fluxo de compra sempre por `/sessions/nearby`, que é o único lugar que devolve o `partnerId`).
3. Registrar como **pendência de backend** no backlog, marcada `[BLOQUEADO-BACKEND]`, e **não** implementar a tela pela metade fingindo que funciona.

Nunca inventar um endpoint "que deveria existir" e mockar no cliente como se fosse real.

## Stack (decisão já tomada — não está em aberto)

- **Flutter** (canal stable) + **Dart 3** — classes `sealed` e *pattern matching* são usados de propósito no tratamento de falhas
- **Gerência de estado: `flutter_bloc`** — decisão do trabalho, não está em discussão. Nada de `setState` em tela que tenha regra; nada de Provider/Riverpod/GetX misturado
- **`equatable`** — igualdade de estados e eventos por valor, requisito para o `bloc` não reconstruir a UI à toa e para `bloc_test` comparar estados
- **HTTP: `dio`** — escolhido por causa dos *interceptors*: o token de acesso é injetado num único ponto, e o tratamento de `401`/erro padronizado do backend também
- **WebSocket: `socket_io_client`** — o backend é Socket.io (não WebSocket puro); um cliente `web_socket_channel` **não** fala esse protocolo. Dois namespaces: `/chat` e `/seats`
- **Navegação: `go_router`** — rotas declarativas com `redirect` reagindo ao estado de autenticação
- **Armazenamento de token: `flutter_secure_storage`** — Keychain/Keystore. `SharedPreferences` **não** serve para token
- **DI: `get_it`** — registro manual, sem `injectable`/codegen (ver "Convenções")
- **QR: `qr_flutter`** (renderizar o código Pix copia-e-cola e o payload do ingresso) + **`mobile_scanner`** (ler QR na tela de validação)
- **Localização: `geolocator`** + **`permission_handler`** — obrigatórios para `GET /sessions/nearby`
- **Imagens: `cached_network_image`** — os pôsteres vêm por URL da CDN do TMDB, o backend não faz proxy (RNF-06)
- **Formatação: `intl`** — locale `pt_BR` para data/hora e para converter centavos em moeda
- **Testes: `bloc_test` + `mocktail`** (+ `flutter_test`). Sem `mockito`/codegen
- **Lint: `flutter_lints`** com regras adicionais em `analysis_options.yaml`

Pacotes deliberadamente **fora**: `json_serializable`/`build_runner` (ver Convenções), `freezed`, `dartz`/`fpdart`, qualquer gerenciador de estado alternativo.

## Convenções

### Estrutura de pastas (feature-first, três camadas)

```
lib/
├── main.dart                  Bootstrap: DI, BlocObserver, runApp
├── app/
│   ├── app.dart               MaterialApp.router + BlocProvider globais
│   ├── router.dart            go_router + redirect por estado de sessão
│   ├── theme.dart
│   └── bloc_observer.dart     Log de transição de estado (debug)
├── core/
│   ├── api/                   ApiClient (dio), interceptors, ApiException
│   ├── ws/                    SocketFactory (namespace + token de handshake)
│   ├── storage/               TokenStorage (secure storage)
│   ├── error/                 Failure (sealed) e mapeamento erro→Failure
│   ├── di/                    injector.dart (get_it)
│   ├── utils/                 formatters, seat_code.dart, paginated.dart
│   └── widgets/               widgets compartilhados entre features
└── features/
    └── <feature>/
        ├── data/
        │   ├── models/        DTO com fromJson/toJson (espelha a resposta da API)
        │   └── <x>_api.dart   Chamadas HTTP cruas da feature
        ├── domain/
        │   ├── entities/      Modelo que a UI consome
        │   └── <x>_repository.dart   Interface (abstract)
        ├── data/repositories/  Implementação do repositório
        └── presentation/
            ├── bloc/          <feature>_bloc.dart / _event.dart / _state.dart
            ├── pages/
            └── widgets/
```

Features previstas (uma por área funcional do backend): `auth`, `profile`, `catalog`, `sessions`, `seats`, `orders`, `payments`, `tickets`, `feed`, `chat`, `notifications`, `demo`.

### Camadas: quem pode falar com quem

```
Page/Widget  →  Bloc  →  Repository (interface)  →  Api/Socket  →  backend
```

- **Widget nunca chama repositório.** Só dispara evento e lê estado.
- **Bloc nunca conhece `dio`, `Response`, JSON ou `DioException`.** Recebe entidade de domínio ou `Failure`.
- **Repositório é a fronteira de tradução**: converte DTO → entidade e exceção de transporte → `Failure`. É também onde vive qualquer junção de dados que a API não faz (ex.: resenha + título do filme).
- **Sem camada de *usecase*.** Decisão consciente: a documentação oficial do `bloc` e o padrão da Very Good Ventures recomendam `data → repository → bloc → UI`. Numa base deste tamanho, uma classe por operação só adicionaria indireção sem regra própria para hospedar. Se um dia uma operação tiver regra que não pertence a nenhum repositório, ela vira um serviço de domínio nomeado — não um `usecase` genérico.

### Bloc vs Cubit

- **Bloc** quando a tela tem três ou mais interações distintas, ou quando recebe eventos de fora do usuário (WebSocket, timer de polling). Ex.: `SeatMapBloc`, `ChatRoomBloc`, `CheckoutBloc`.
- **Cubit** quando é carregar-e-mostrar, com no máximo um "recarregar". Ex.: `CatalogCubit`, `ProfileCubit`.
- Na dúvida, Bloc. A regra existe para evitar Cubit com oito métodos, que é um Bloc mal escrito.

### Formato de estado (padrão único, sem exceções)

Uma classe de estado por Bloc, com `status`, `Equatable` e `copyWith`:

```dart
enum StateStatus { initial, loading, success, failure }

class SeatMapState extends Equatable {
  const SeatMapState({
    this.status = StateStatus.initial,
    this.seats = const [],
    this.selectedSeatIds = const {},
    this.failure,
  });

  final StateStatus status;
  final List<Seat> seats;
  final Set<int> selectedSeatIds;
  final Failure? failure;
  // copyWith + props
}
```

**Por que estado único em vez de estados `sealed` separados:** o mapa de assentos recebe atualização por WebSocket enquanto o usuário já está olhando a tela. Com estados separados (`Loading` / `Loaded`), qualquer recarga descarta os dados anteriores e a tela pisca. Com `status` + dados preservados, dá para mostrar "atualizando" sobre a lista que já está lá. A consistência vale mais que a elegância de cada caso isolado — **um formato só para todos os Blocs**.

`sealed class` é usada, sim, mas para **falhas** (`Failure`), onde o *pattern matching* exaustivo do Dart 3 realmente paga.

### Nomenclatura

- Arquivos e pastas em `snake_case`; classes em `PascalCase`.
- Eventos no **imperativo**, descrevendo o que o usuário/sistema fez: `SeatMapRequested`, `SeatTapped`, `SeatLockedByOther` (evento vindo do WS). Nunca `LoadSeats`/`SetSeats` — evento não é comando de setter.
- Estados não têm nome próprio: existe `<Feature>State`, uma classe só.
- DTO de resposta termina em `Model` (`MovieModel`); entidade de domínio é o nome puro (`Movie`).

### Serialização: `fromJson` escrito à mão

Sem `json_serializable`/`build_runner`. Motivo: são cerca de vinte DTOs pequenos, e o mapeamento explícito é onde as peculiaridades da API ficam visíveis — `Review.text` que chega `null` quando é spoiler, `priceCents` inteiro, datas como string ISO. Um `@JsonKey` esconderia isso atrás de codegen. O custo (escrever `fromJson`) é baixo; o ganho (nenhuma etapa de build, mapeamento legível na defesa do trabalho) é alto.

Regra: **DTO espelha a resposta da API literalmente**; conversão (string ISO → `DateTime`, centavos → `Money`) acontece ao virar entidade, não no `fromJson`.

### Injeção de dependência

`get_it` com registro manual em `core/di/injector.dart`, em três blocos: `singleton` para infraestrutura (`Dio`, `TokenStorage`, `SocketFactory`), `lazySingleton` para repositórios, `factory` para Blocs. Blocs **nunca** são singleton — um Bloc por instância de tela, descartado com ela.

Blocs de sessão global (`AuthBloc`) são a única exceção: instanciados uma vez em `app.dart` via `BlocProvider`.

### Tratamento de erro

O backend tem **formato único de erro** (`../backend/src/common/filters/all-exceptions.filter.ts`):

```json
{ "statusCode": 409, "error": "Conflict", "message": "...", "requestId": "...", "timestamp": "...", "path": "..." }
```

**Armadilha real:** `message` é `string` **ou** `string[]`. Quando o `ValidationPipe` global rejeita o corpo, vem um array (`["email must be an email", "password must be longer..."]`). O parser de erro precisa tratar os dois casos — tratar só como string produz `"[object Object]"` na tela.

Todo erro vira uma `Failure` (sealed) antes de chegar ao Bloc:

| `Failure` | Origem |
|---|---|
| `NetworkFailure` | Sem conexão, timeout do `dio` |
| `UnauthorizedFailure` | 401 — token ausente, inválido ou **expirado** |
| `ForbiddenFailure` | 403 — recurso de outro usuário |
| `NotFoundFailure` | 404 |
| `ConflictFailure` | 409 — assento não reservado, pedido já pago, e-mail duplicado |
| `ValidationFailure` | 400 — carrega a lista de mensagens |
| `ServerFailure` | 5xx — mensagem genérica; o backend **não** manda detalhe, por design |

O `requestId` do corpo do erro deve ser guardado no log do app: é o mesmo id que aparece no log estruturado do backend, e é o que torna um bug reproduzível rastreável dos dois lados.

### Autenticação e o problema do refresh

`POST /auth/login` devolve `accessToken` (15 min) **e** `refreshToken` (7 dias) — mas **o backend não expõe endpoint de renovação**. Confirmado por leitura de `../backend/src/modules/auth/auth.controller.ts`: só existem `register` e `login`.

Consequência para este app, que precisa estar documentada e não escondida: **quando o access token expira, a sessão acaba**. O interceptor do `dio` deve, ao receber 401, limpar o armazenamento seguro e emitir `AuthLogoutRequested`, levando o usuário ao login. Guardar senha para re-login automático **não é uma opção** — seria trocar uma limitação de escopo por uma falha de segurança real.

O `refreshToken` é guardado mesmo assim (é o que o backend devolve, e o dia em que `POST /auth/refresh` existir, o interceptor muda num ponto só). Está registrado como `[BLOQUEADO-BACKEND]` no backlog.

### WebSocket

- Um namespace por feature: `/chat` (`ChatGateway`) e `/seats` (`SeatsGateway`).
- Autenticação no handshake: `IO.io(url, OptionBuilder().setAuth({'token': accessToken})...)`. É a convenção do próprio Socket.io e a que o backend lê primeiro (`../backend/src/websocket/ws-auth.middleware.ts`).
- **O socket também morre quando o access token expira** — a reconexão automática do Socket.io vai falhar no handshake. Tratar `connect_error` como sessão expirada, mesmo caminho do 401 HTTP.
- Conexão é **por tela**, aberta no `Bloc` e fechada no `close()`. Não manter socket global aberto: gasta bateria e complica o ciclo de vida.
- Todo evento recebido do servidor entra no Bloc como **evento** (`SeatLockedReceived`), nunca chama `emit` direto de dentro do callback.

### Assentos: o layout não vem da API

`GET /sessions/:id/seats/map` devolve `[{ seatId, code, status }]` — **não devolve linha, coluna nem geometria**. O `code` é uma string tipo `"A1"`, `"B12"` (convenção do backend em `Seat.code`).

Convenção deste app: `core/utils/seat_code.dart` separa `code` em prefixo alfabético (fileira) e sufixo numérico (posição), agrupa por fileira e ordena. Assento com código fora desse padrão vai para uma fileira "outros" em vez de quebrar a tela. Essa regra vive num único arquivo, com teste unitário — não espalhada por widget.

### Dinheiro

Tudo em **centavos inteiros** (`priceCents`, `totalAmountCents`) — igual ao backend, que nunca usa ponto flutuante para dinheiro. A conversão para exibição (`R$ 32,50`) acontece só na camada de apresentação, via `intl`. **Nunca** guardar valor monetário em `double` no app.

### Datas

Todas as datas da API são strings ISO 8601 com timezone (`TimestamptzString` no contrato do backend). Converter com `DateTime.parse(...).toLocal()` na fronteira do repositório, exibir com `intl`. Nunca comparar strings de data.

## Ambiente de desenvolvimento

### Endereço do backend

| Cenário | `API_BASE_URL` |
|---|---|
| Emulador Android | `http://10.0.2.2:3000` |
| Simulador iOS / desktop | `http://localhost:3000` |
| Dispositivo físico na mesma rede | `http://<ip-da-máquina>:3000` |

**Armadilha clássica:** `localhost` dentro do emulador Android aponta para o próprio emulador, não para a máquina. `10.0.2.2` é o alias do host. Isso já custou tempo em todo projeto Flutter que fala com API local — está aqui para não custar de novo.

Configuração via `--dart-define`, nunca hardcoded:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Android precisa de `android:usesCleartextTraffic="true"` no manifesto de debug para HTTP sem TLS — só na configuração de debug, nunca em release.

### Subir o backend

Na raiz do projeto (`../`):

```bash
docker compose up -d
```

Sobe API (`:3000`), PostgreSQL (`:5432`) e Redis (`:6379`). Sem Redis no ar, o mapa de assentos e o chat não funcionam — o lock de assento e o broadcast entre instâncias dependem dele.

Verificar antes de acusar o app: `GET http://localhost:3000/health` deve devolver `{"status":"ok","database":"ok","redis":"ok"}`. Esse endpoint fica **fora** do prefixo `/api/v1` de propósito.

### Massa de dados

O backend não tem `seed`. Para existir sessão, sala, assento e combo é preciso chamar os endpoints de cadastro (`POST /partners`, `/partners/:id/rooms`, `/rooms/:id/seats`, `/sessions`, `/partners/:id/combos`) — todos exigem apenas um JWT válido, **sem papel de administrador** (é uma simplificação declarada do backend). Filmes chegam sozinhos: o job de sincronização do TMDB roda no boot da API.

Manter um script HTTP versionado (`tool/seed.http` ou similar) com essa sequência. **Não** construir tela de cadastro administrativo no app do usuário final — ver `ARQUITETURA_FRONTEND.md` § "Escopo de telas".

## Comandos

```bash
flutter pub get              # instala dependências
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
flutter analyze              # lint (o que o CI roda)
dart format --set-exit-if-changed lib test
flutter test                 # testes unitários e de widget
flutter test integration_test  # teste de integração (exige backend no ar)
flutter build apk --release
```

## Como trabalhar as tasks

- As tasks estão em `BACKLOG_FRONTEND.md`, agrupadas por fase, numeradas `FE-XX`.
- Cada task cita **o requisito de origem (RF/RNF)** e **os endpoints/eventos do backend que consome**. Antes de implementar, abrir o arquivo do backend citado e conferir a forma real da resposta — a task descreve, o código do servidor decide.
- Ao concluir: marcar `[x]`, garantir teste (`bloc_test` para todo Bloc, no mínimo), e atualizar este `CLAUDE.md` se alguma convenção mudou.
- Task marcada `[BLOQUEADO-BACKEND]` **não deve ser contornada com dado falso no cliente**. Implementar o que dá, deixar o restante explicitamente indisponível na UI, e manter o bloqueio registrado.

## Fora de escopo (não implementar)

Herdado do recorte do backend e confirmado com o cliente:

- Painel B2B, analytics ou qualquer tela de gestão para o cinema parceiro (decisão explícita, 29/08/2026)
- Integração real com múltiplas redes de cinema
- Catraca/validação 100% offline
- Fidelidade, gamificação, recomendação por IA
- Postagem direta em rede social — o compartilhamento usa a *share sheet* nativa com os metadados que `GET /reviews/:id/share` devolve; o backend não integra com nenhuma rede
- Flutter **Web** como alvo. O backend não habilita CORS (`app.enableCors()` não é chamado em `main.ts`), então o app rodando em navegador seria bloqueado. Alvo é Android e iOS

## Armadilhas já conhecidas (antes da primeira linha de código)

Levantadas por leitura do backend, não por tentativa e erro — cada uma tem o arquivo que a comprova:

1. **`message` de erro pode ser array** — `all-exceptions.filter.ts`. Tratar os dois formatos.
2. **Não existe renovação de token** — `auth.controller.ts`. 401 = fim de sessão.
3. **Não existe rota que devolva um ingresso comprado** — `tickets.controller.ts` só tem `POST /validate`. O QR é gerado no servidor e nunca sai de lá. Ver `ARQUITETURA_FRONTEND.md` § "Atritos conhecidos", item 1: é o maior bloqueio funcional do app.
4. **Não existe busca de usuário** — criar sala de chat exige `memberIds` numéricos. O único lugar de onde o app tira um `userId` de outra pessoa é o autor de uma resenha no feed. Isso **define** o ponto de entrada do chat.
5. **`GET /sessions` não devolve `partnerId`** — e não existe `GET /rooms/:id`. O `partnerId` (necessário para listar combos) só aparece em `GET /sessions/nearby`. A navegação de compra tem que passar por lá.
6. **Resenha não traz nome do autor nem título do filme** — só `userId` e `movieId`. Junção é responsabilidade do repositório do app.
7. **Confirmação de Pix não chega ao app** — o webhook é do provedor para o backend. O app descobre por *polling* em `GET /orders/:orderId/payments`.
8. **Push nunca chega de verdade** — `MockPushSender` apenas escreve no log do servidor. O app registra o token normalmente (`POST /push-tokens`), mas nenhuma notificação será entregue enquanto não houver Firebase real.
9. **`GET /users/me/profile` devolve 404 quando o perfil ainda não foi criado** — é o comportamento esperado, não erro. Tratar como "perfil vazio", não como falha.
10. **O lock de assento expira em 5 minutos** (`SEAT_LOCK_TTL_SECONDS`). O checkout precisa de cronômetro visível; passar disso, o assento volta a ficar livre e `POST /orders` responde 409.
