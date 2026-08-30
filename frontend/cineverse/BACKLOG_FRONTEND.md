# Backlog de Frontend — CineVerse (Flutter + BLoC)

> Tasks organizadas por fase, numeradas `FE-XX`. Cada uma cita **o requisito de origem** e **os endpoints/eventos do backend que consome** — o backend já existe (`../backend`) e é a fonte da verdade: a task descreve, o código do servidor decide a forma real da resposta.
>
> Ver `ARQUITETURA_FRONTEND.md` para o desenho e `CLAUDE.md` para convenções.

**Formato:** `FE-XX — Título` · origem · descrição · **Consome:** · *Critério de aceite*

**Marcadores:** `[BLOQUEADO-BACKEND]` = depende de rota que não existe no servidor; não contornar com dado falso.

---

## Fase 0 — Fundação

- [ ] **FE-01 — Criação do projeto Flutter**: `flutter create`, estrutura de pastas de `ARQUITETURA_FRONTEND.md` § 3, `analysis_options.yaml` com `flutter_lints`, `.gitignore`. *Critério: `flutter analyze` e `dart format --set-exit-if-changed` passam num projeto vazio; a árvore `lib/core` + `lib/features` existe.*

- [ ] **FE-02 — Dependências e configuração de ambiente**: adicionar as dependências fixadas em `CLAUDE.md` (Stack); `API_BASE_URL` via `--dart-define`, sem valor hardcoded; `usesCleartextTraffic` apenas no manifesto de debug. *Critério: o app compila para Android e iOS e lê a URL base do `--dart-define`; nenhum endereço de servidor aparece no código.*

- [ ] **FE-03 — Cliente HTTP e interceptor de autenticação** · RNF transversal. `ApiClient` sobre `dio` (baseUrl `/api/v1`, timeouts), `AuthInterceptor` injetando `Authorization: Bearer` e reagindo a `401`. **Consome:** qualquer rota protegida. *Critério: uma requisição sem token guardado sai sem o header; com token, sai com ele; um `401` limpa o armazenamento seguro e notifica o `AuthBloc`.*

- [ ] **FE-04 — Mapeamento de erro do backend** · RNF transversal. `Failure` (sealed) + `failure_mapper.dart` cobrindo 400/401/403/404/409/5xx/rede, tratando `message` como **`String` ou `List<String>`**. **Consome:** formato de `../backend/src/common/filters/all-exceptions.filter.ts`. *Critério: teste unitário com corpo de erro real dos dois formatos produz `Failure` correta e mensagem legível; o `requestId` é preservado para log.*

- [ ] **FE-05 — Armazenamento seguro de token**: `TokenStorage` sobre `flutter_secure_storage` (salvar, ler, limpar). *Critério: token sobrevive ao fechamento do app; logout apaga; nada de token em `SharedPreferences`.*

- [ ] **FE-06 — Injeção de dependência**: `get_it` em `core/di/injector.dart`, com as três categorias de registro (`singleton` infra, `lazySingleton` repositórios, `factory` Blocs). *Critério: `main.dart` chama um único `setupDependencies()`; nenhum `new Repository()` espalhado por widget.*

- [ ] **FE-07 — Navegação e tema**: `go_router` com o mapa de rotas de `ARQUITETURA_FRONTEND.md` § 6, `redirect` por estado de sessão, shell com barra inferior; tema claro/escuro; `BlocObserver` logando transições em debug. *Critério: rota protegida acessada sem sessão redireciona para `/login` a partir de qualquer ponto do app.*

- [ ] **FE-08 — CI do frontend**: workflow rodando `flutter analyze`, `dart format --set-exit-if-changed` e `flutter test` a cada push/PR. *Critério: PR quebra o build se lint, formatação ou teste falhar.*

---

## Fase 1 — Identidade e Perfil (RF-01, RF-02)

- [ ] **FE-09 — `AuthBloc` e sessão global** · RF-01. Estados de sessão (desconhecida, autenticada, anônima), eventos de login/cadastro/logout/expiração; restauração do token no início. **Consome:** `POST /api/v1/auth/login`, `POST /api/v1/auth/register`. *Critério: `bloc_test` cobre login com sucesso, credencial inválida (401), e-mail duplicado (409) e expiração de sessão.*

- [ ] **FE-10 — Tela de login** · RF-01. Formulário com validação local (e-mail válido, senha 8–72), estados de carregamento e erro, mensagem genérica em credencial inválida. **Consome:** `POST /auth/login`. *Critério do RF: usuário autentica em menos de 1 minuto. Além disso: a tela não diferencia "e-mail não existe" de "senha errada" — o backend não diferencia de propósito, e a UI não deve inventar essa distinção.*

- [ ] **FE-11 — Tela de cadastro** · RF-01. Nome opcional, e-mail, senha com limite de 72 caracteres explicado na UI. **Consome:** `POST /auth/register`. *Critério: cadastro bem-sucedido leva direto ao app autenticado; e-mail já usado exibe a mensagem de conflito do servidor.*

- [ ] **FE-12 — Splash e restauração de sessão** · RF-01. Decide entre `/login` e o app conforme token guardado; se a rede estiver fora, consulta `GET /health` para distinguir "servidor fora" de "sem internet". **Consome:** `GET /health` (público, fora de `/api/v1`). *Critério: abrir o app com sessão válida não passa pela tela de login; sem rede, a mensagem diz qual é o problema.*

- [x] **FE-13 — Perfil e gêneros favoritos** · RF-02. `ProfileBloc` (não Cubit — carregar, alternar gênero e salvar são 3 interações distintas, ver CLAUDE.md § Bloc vs Cubit); seleção múltipla de gêneros com **substituição total** ao salvar; **`404` significa perfil ainda não criado**, não erro. E-mail exibido vem do claim `email` do access token guardado (não existe `GET /users/me`) — nome não é exibido, não há como obtê-lo para uma sessão já autenticada. Lista de gêneros é fixa no cliente (backend não expõe nem restringe valores). Botão de logout confirma antes de encerrar a sessão. **Consome:** `GET/PUT /users/me/profile`. *Critério: primeiro acesso mostra estado vazio (não tela de erro); salvar e recarregar devolve exatamente a seleção enviada.*

---

## Fase 2 — Catálogo e Descoberta (RF-06, RF-07)

- [x] **FE-14 — Catálogo em cartaz/lançamento/em breve** · RF-06. `CatalogBloc` com uma aba (`CategoryFeed`) por categoria, cada uma com sua própria rolagem infinita (`pageSize` 20), pôsteres via `cached_network_image`, estados vazio/erro/carregando independentes por aba. A categoria é derivada de `releaseDate` **no backend** (`em_cartaz`/`lancamento`/`em_breve`, com janela de 21 dias para "lançamento") — o cliente só filtra/pagina, não recalcula data. **Consome:** `GET /catalog/movies?page=&pageSize=&category=`. *Critério: lista os filmes que o job de sincronização do TMDB gravou (now_playing + upcoming); trocar de aba não perde a posição de rolagem nem refaz a requisição já bem-sucedida; rolar até o fim de uma aba carrega a próxima página sem duplicar itens.*

- [ ] **FE-15 — Cache de catálogo compartilhado** · RF-06. O `CatalogRepository` mantém em memória os filmes já carregados e expõe `movieById` — é a fonte das junções que a API não faz. **Consome:** o mesmo endpoint. *Critério: o feed (FE-19) resolve título e pôster pelo `movieId` sem requisição adicional quando o filme já foi carregado.*

- [ ] **FE-16 — Detalhe do filme** · RF-06. Montado a partir do item já em cache (não existe `GET /catalog/movies/:id`); mostra sinopse, pôster e as resenhas do filme presentes no feed já carregado, com aviso de que são as recentes. *Critério: abrir o detalhe não dispara requisição nova; a limitação do recorte de resenhas está declarada na própria tela.*

- [ ] **FE-17 — Permissão e captura de localização** · RF-07. `geolocator` + `permission_handler`, com os três caminhos tratados: concedida, negada, negada permanentemente (abrir ajustes). *Critério: negar a permissão não trava a tela nem gera erro genérico — exibe explicação e ação de reversão.*

- [ ] **FE-18 — Cinema próximo e sessões** · RF-07. `NearbySessionsBloc`: coordenadas → parceiro mais próximo + sessões futuras, com distância em km, horários e preço formatado em reais. **Guarda o `partnerId` no estado — é a única fonte desse dado em toda a API.** **Consome:** `GET /sessions/nearby?lat=&lng=`. *Critério: a lista traz apenas sessões futuras; `404` (nenhum parceiro cadastrado) vira estado vazio explicativo, não erro.*

---

## Fase 3 — Social: Feed e Chat (RF-03, RF-04, RF-05, RF-16)

- [ ] **FE-19 — Feed de resenhas** · RF-03. `FeedBloc` com rolagem infinita, mais recentes primeiro; cada item resolve título/pôster pelo cache do catálogo (FE-15) e exibe autor como identificador anônimo consistente — **não existe rota que traduza `userId` em nome**. **Consome:** `GET /reviews?page=&pageSize=`. *Critério: feed carrega paginado sem duplicar itens; a limitação do nome do autor está registrada, não disfarçada.*

- [ ] **FE-20 — Ofuscação de spoiler** · RF-04. Item com `hasSpoiler:true` chega com `text: null` **do servidor** — a UI mostra o marcador e o botão "revelar", nunca um texto borrado por cima do conteúdo real. **Consome:** `GET /reviews` (comportamento de `FeedService.obfuscateIfSpoiler`). *Critério: inspecionar a resposta de rede não revela o texto de uma resenha com spoiler.*

- [ ] **FE-21 — Revelar resenha** · RF-04. Ação explícita que busca o texto real e o mantém revelado enquanto a tela existir. **Consome:** `GET /reviews/:id/reveal`. *Critério: revelar afeta apenas aquele item; sair e voltar à tela restaura o estado oculto.*

- [ ] **FE-22 — Publicar resenha** · RF-03. `ReviewComposerCubit`: escolha de filme (do catálogo), nota 1–5, texto até 2000, marcação de spoiler. **Consome:** `POST /reviews`. *Critério do RF: resenha publicada aparece no feed. O autor vê o próprio texto imediatamente, mesmo marcado como spoiler — o backend devolve o texto real a quem acabou de escrever.*

- [ ] **FE-23 — Compartilhamento externo** · RF-16. Usa a *share sheet* nativa com os metadados prontos do servidor; resenha com spoiler compartilha a mensagem genérica, nunca o texto. **Consome:** `GET /reviews/:id/share`. *Critério: o conteúdo compartilhado vem do servidor, sem texto montado no cliente; spoiler não vaza pelo compartilhamento.*

- [ ] **FE-24 — Lista de conversas** · RF-05. `ChatRoomsBloc` paginado. **Consome:** `GET /chat/rooms?page=&pageSize=`. *Critério: lista as salas do usuário autenticado; estado vazio explica como iniciar uma conversa (a partir de uma resenha).*

- [ ] **FE-25 — Iniciar conversa a partir de uma resenha** · RF-05. Único ponto de entrada possível: o feed devolve o `userId` do autor, e **não existe busca de usuário** na API. Conversa individual é *get-or-create* no servidor. **Consome:** `POST /chat/rooms {type:"individual", memberIds:[autorId]}`. *Critério: iniciar conversa duas vezes com a mesma pessoa abre a mesma sala, não duas.*

- [ ] **FE-26 — Conversa em tempo real** · RF-05. `ChatRoomBloc`: histórico paginado (`createdAt desc`, exibido invertido) + socket `/chat` com `joinRoom`/`sendMessage`/`newMessage`; **deduplicação da própria mensagem**, que volta pelo broadcast; reenvio do `joinRoom` ao reconectar. **Consome:** `GET /chat/rooms/:roomId/messages`, WS `/chat`. *Critério do RF: mensagem entre dois usuários em menos de 2 s (medição do backend: ~17 ms). A própria mensagem aparece uma vez só, nunca duplicada.*

---

## Fase 4 — Assentos e Compra (RF-08, RF-09, RF-10, RF-15, RD-02, RNF-08)

- [ ] **FE-27 — Derivação do layout de assentos** · RF-10. `core/utils/seat_code.dart`: separa `"A12"` em fileira e posição, agrupa e ordena; código fora do padrão vai para uma fileira "outros" em vez de quebrar a tela. **A API não devolve linha/coluna.** *Critério: teste unitário cobre códigos normais, fileira de duas letras, código inesperado e lista vazia.*

- [ ] **FE-28 — Mapa de assentos (snapshot)** · RF-10. `SeatMapBloc` carregando o mapa REST, com legenda de estados (disponível/reservado/vendido) e `Semantics` por assento. **Consome:** `GET /sessions/:sessionId/seats/map`. *Critério: o mapa reflete o estado do servidor; assento vendido e reservado não são selecionáveis.*

- [ ] **FE-29 — Mapa em tempo real** · RF-10, RD-02. Socket `/seats`: `joinSession`, recepção de `seat_locked`/`seat_released`/`seat_sold` atualizando **um assento por vez** sem descartar a seleção; ressincronização do snapshot ao reconectar; assento selecionado que for tomado por outro sai da seleção com aviso. **Consome:** WS `/seats`. *Critério do RD-02: assento vendido em outro dispositivo desaparece do app em tempo real (medição do backend: ~28 ms), sem recarregar a tela.*

- [ ] **FE-30 — Seleção e reserva atômica** · RF-09, RNF-08. Seleção local de até 20 assentos; reserva via **REST**, não por evento WS — o REST é tudo-ou-nada. `success:false` (que vem em resposta de sucesso HTTP, não erro) volta ao mapa com a razão do servidor. **Consome:** `POST /sessions/:sessionId/seats/lock`. *Critério: o app nunca marca assento como reservado antes da resposta do servidor; recusa exibe o motivo e não avança o fluxo.*

- [ ] **FE-31 — Cronômetro do lock** · RNF-08. Contador visível de 5 minutos (`SEAT_LOCK_TTL_SECONDS`) a partir da reserva; ao zerar, limpa a seleção e volta ao mapa. *Critério: o usuário nunca chega ao pagamento com reserva expirada sem ter sido avisado.*

- [ ] **FE-32 — Liberação ao abandonar** · RNF-08. Sair do fluxo (voltar, fechar, trocar de sessão) chama a liberação, refletindo **apenas os assentos que o servidor confirmou** liberados. **Consome:** `POST /sessions/:sessionId/seats/release`. *Critério: assento abandonado volta a ficar disponível para outro usuário imediatamente, sem esperar o TTL.*

- [ ] **FE-33 — Combos por assento** · RF-15. Lista de combos do parceiro (usando o `partnerId` guardado em FE-18), escolha **por assento** — pessoas diferentes no mesmo pedido podem pedir combos diferentes ou nenhum. **Consome:** `GET /partners/:partnerId/combos`. *Critério do RF: o combo aparece como opção no checkout e o total previsto reflete ingresso + combos escolhidos.*

- [ ] **FE-34 — Checkout: criação do pedido** · RF-08, RF-09. `CheckoutBloc` monta `items:[{seatId, comboItemId?}]` e cria o pedido; **`409` significa lock expirado** — volta ao mapa em vez de repetir. O valor oficial é o `totalAmountCents` devolvido pelo servidor, não o calculado localmente. **Consome:** `POST /orders`. *Critério do RF-08: da seleção do assento à tela de pagamento em até 3 interações (reservar → confirmar pedido → pagar). Critério do RF-09: um único checkout com N assentos gera um pedido com N itens.*

---

## Fase 5 — Pagamentos (RF-11, RF-12)

- [ ] **FE-35 — Escolha de método de pagamento** · RF-11, RF-12. Pix, Apple Pay, Google Pay e cartão; **nenhum formulário de número de cartão, validade ou CVV** — o backend não tem esses campos e os rejeita com `400`. A tela deixa explícito que carteira e cartão usam token simulado nesta versão. **Consome:** `POST /orders/:orderId/payments`. *Critério: enviar qualquer campo de cartão é impossível pela UI; a natureza simulada do token está declarada na tela, não escondida.*

- [ ] **FE-36 — Pagamento por Pix** · RF-11. Renderiza o `copyPasteCode` como QR (`qr_flutter`) + botão de copiar; estado de espera explícito. **Consome:** `POST /orders/:orderId/payments {method:"pix"}`. *Critério: o código exibido é exatamente o que o servidor devolveu; a tela informa que o código é simulado e não será reconhecido por um banco real.*

- [ ] **FE-37 — Confirmação assíncrona do Pix** · RF-11. *Polling* de `GET /orders/:orderId/payments` a cada 3 s, limite de 5 minutos, **encerrado ao sair da tela**. **Consome:** `GET /orders/:orderId/payments`. *Critério: quando o webhook confirma no servidor, o app reflete "pago" em até 3 s; sair da tela interrompe o polling (verificável no log de rede).*

- [ ] **FE-38 — Pagamento síncrono e estados finais** · RF-11, RF-12. Carteira/cartão confirmam na própria resposta; `failed` deixa o pedido travado (**um pagamento por pedido**), então a UI informa e oferece iniciar nova compra — nunca "tentar de novo", que sempre daria `409`. *Critério: pagamento aprovado leva à confirmação com o total correto; recusado explica que o pedido não aceita nova tentativa.*

---

## Fase 6 — Ingressos (RF-13, RF-14, RNF-12)

- [ ] **FE-39 — Confirmação de compra** · RF-08. Tela final com resumo: filme, sessão, assentos (código, não id), combos e total. *Critério: os dados vêm do pedido devolvido pelo servidor, com códigos de assento resolvidos pelo mapa já carregado.*

- [ ] **FE-40 — Exibição do ingresso** · RF-13. `[BLOQUEADO-BACKEND]` — **nenhuma rota devolve o `qrCodePayload` de um ingresso comprado**; o `Ticket` é criado no servidor e nunca sai de lá (`../backend/src/modules/tickets/tickets.controller.ts` só expõe `POST /validate`). *Ação: implementar a tela com estado explícito de indisponibilidade ("ingresso gerado — exibição indisponível nesta versão"). **Proibido** gerar um QR no cliente para simular. Destrava com uma rota `GET /orders/:orderId/tickets` no backend — ver "Pendências de backend".*

- [ ] **FE-41 — Leitor e validação de ingresso** · RF-14, RNF-12. Câmera (`mobile_scanner`) lê o QR e envia o payload cru; resposta **sempre `200`** com `valid` e `reason` — `valid:false` **não é erro**, é resultado. Três desfechos distintos na UI: válido, já utilizado, inválido/adulterado. **Consome:** `POST /tickets/validate`. *Critério do RF-14: ingresso válido é aceito e passa a "usado"; a segunda leitura do mesmo código informa "já utilizado". Critério do RNF-12: resposta em menos de 500 ms (medição do backend: ~5–10 ms).*

---

## Fase 7 — Notificações (RF-17)

- [ ] **FE-42 — Registro de token de dispositivo** · RF-17. Após login, registra o token (FCM se houver projeto Firebase; identificador de instalação caso contrário — o backend aceita qualquer string) com a plataforma correta. Resposta é **`200`**, não 201, e reregistrar é idempotente. **Consome:** `POST /push-tokens`. *Critério: o mesmo dispositivo registrado duas vezes não cria duas linhas no servidor; `platform` fora de `ios`/`android` nem é enviado.*

- [ ] **FE-43 — Recepção de notificação** · RF-17. `[BLOQUEADO-BACKEND]` — o servidor usa `MockPushSender`, que apenas escreve no log; **nenhuma notificação é entregue de verdade**. *Ação: deixar o app preparado para receber (permissão de notificação, tratamento de toque abrindo a sessão correspondente) e declarar que a entrega não é verificável nesta versão. Destrava com um projeto Firebase real e a substituição do `MockPushSender` no backend.*

---

## Fase 8 — Transversais e Qualidade

- [ ] **FE-44 — Estados vazios, de erro e de carregamento padronizados**: widgets compartilhados (`EmptyState`, `AppErrorView`, `AppLoader`) usados por todas as listagens, com a regra de `409` exibindo a mensagem do servidor e os demais status usando texto próprio do app. *Critério: nenhuma tela mostra `Exception:` ou texto técnico ao usuário; nenhuma lista vazia aparece como tela em branco.*

- [ ] **FE-45 — Sessão expirada em qualquer ponto**: `401` HTTP e `connect_error` de socket levam ao mesmo caminho — encerrar sessão e redirecionar, inclusive no meio do checkout, liberando os assentos reservados antes de sair. *Critério: expirar o token durante o fluxo de compra não deixa assento preso nem tela travada.*

- [ ] **FE-46 — Formatação pt-BR**: `intl` para data/hora local (as datas chegam em ISO com timezone) e centavos → `R$ 0,00`. **Nenhum valor monetário em `double` no app.** *Critério: teste unitário do formatador; nenhuma data comparada como string em nenhum lugar.*

- [ ] **FE-47 — Acessibilidade**: `Semantics` no mapa de assentos (código + estado), contraste mínimo, alvos de toque ≥ 48 dp, suporte a fonte ampliada nas telas de compra. *Critério: leitor de tela anuncia "assento A12, disponível"; a tela de checkout permanece utilizável com fonte ampliada.*

- [ ] **FE-48 — Desempenho de listas** · RNF-06. `ListView.builder` em todas as listagens, `cached_network_image` para pôsteres, nenhuma requisição em laço sem limite, polling apenas com a tela visível. *Critério: rolagem do catálogo e do feed sem travamento perceptível com várias páginas carregadas.*

---

## Fase 9 — Testes e Validação

- [ ] **FE-49 — Testes de Bloc**: `bloc_test` para todos os Blocs do catálogo (`ARQUITETURA_FRONTEND.md` § 5), cobrindo caminho feliz **e** falha. *Critério: todo Bloc tem ao menos um teste de sucesso e um de falha; `flutter test` verde no CI.*

- [ ] **FE-50 — Testes unitários das regras com armadilha**: `seat_code`, formatador de moeda, `failure_mapper` (incluindo `message` como array) e `fromJson` dos DTOs com campos anuláveis (`Review.text`, `posterUrl`, `comboItemId`). *Critério: cada armadilha listada em `CLAUDE.md` § "Armadilhas" que seja testável tem teste correspondente.*

- [ ] **FE-51 — Testes de widget das telas com regra visual**: mapa de assentos (estados e seleção), resenha com spoiler oculto/revelado, cronômetro do lock, tela de pagamento sem campo de cartão. *Critério: o teste do spoiler falha se o texto real chegar à árvore de widgets.*

- [ ] **FE-52 — Teste de integração do fluxo de compra** · RF-08, RF-09. `integration_test` contra backend real local: login → sessão próxima → reserva → pedido com combo → pagamento → confirmação. *Critério: o cenário completo passa com o `docker compose` do projeto no ar.*

- [ ] **FE-53 — Validação manual multiusuário** · RF-05, RF-10, RNF-08. Dois dispositivos simultâneos: mensagem de chat entre eles; disputa pelo mesmo assento (um vence, o outro recebe recusa); venda propagando no mapa do outro. *Critério: registrar as medições observadas, como foi feito no backend, para constar no TCC.*

---

## Fase 10 — Entrega e Demonstração

- [ ] **FE-54 — Script de massa de dados**: `tool/seed.http` versionado com a sequência de cadastro (parceiro com coordenadas → sala → assentos → sessão → combos), já que o backend não tem `seed`. *Critério: um ambiente limpo fica demonstrável rodando o script e esperando o job do TMDB popular os filmes.*

- [ ] **FE-55 — Área de demonstração (opcional)**: tela oculta no perfil para disparar `POST /notifications/broadcast` e validar um `qrCodePayload` colado manualmente, **visivelmente rotulada como ferramenta de demonstração**. *Critério: não é acessível pela navegação normal e não se disfarça de funcionalidade do produto.*

- [ ] **FE-56 — Build de release e roteiro de demonstração**: APK assinado de release e roteiro escrito da apresentação, na ordem que exercita os requisitos. *Critério: a demonstração roda ponta a ponta sem intervenção no banco durante a apresentação.*

---

## Pendências de backend descobertas pelo frontend

Não são tasks deste backlog — são o que o cliente precisa e o servidor ainda não oferece. Registradas aqui porque foram descobertas ao desenhar o app, e porque a decisão de implementá-las ou não é do trabalho como um todo.

| # | Falta no backend | Impacto no app | Tamanho estimado |
|---|---|---|---|
| 1 | **`GET /orders/:orderId/tickets`** (ou tickets embutidos em `GET /orders/:id`) | FE-40 fica bloqueada — o usuário **não consegue ver o ingresso que comprou**. É o que falta para o fluxo fechar de ponta a ponta | Pequeno: uma consulta por `orderItemId`, no padrão de posse que `OrdersService` já usa |
| 2 | **`POST /auth/refresh`** | Sessão dura 15 minutos; expirar no meio do uso força novo login (FE-45) | Pequeno: verificar o refresh token e reemitir o par |
| 3 | **`GET /users/:id`** ou nome do autor embutido em `GET /reviews` | Feed mostra "Cinéfilo #42" em vez do nome (FE-19) | Pequeno |
| 4 | **`GET /reviews?movieId=`** | Detalhe do filme mostra recorte parcial das resenhas (FE-16) | Pequeno: um filtro na consulta existente |
| 5 | **`GET /sessions/:id`** devolvendo `partnerId`, ou `GET /rooms/:id` | Obriga o fluxo de compra a entrar por `/nearby` (contornado por desenho, não bloqueia) | Pequeno |
| 6 | Envio real de push (Firebase no lugar do `MockPushSender`) | FE-43 não é verificável | Depende de projeto Firebase |
| 7 | `app.enableCors()` | Impede Flutter Web (fora de escopo por decisão) | Uma linha |

**Prioridade:** o item 1 é o único que impede um requisito funcional de ser demonstrado (RF-13). Os demais degradam a experiência ou o escopo, mas têm contorno no cliente.

---

## Rastreabilidade requisito → tasks

| Requisito | Tasks | Situação prevista ao fim do backlog |
|---|---|---|
| RF-01 — Cadastro e autenticação | FE-09, FE-10, FE-11, FE-12 | Completo |
| RF-02 — Perfil e preferências | FE-13 | Completo |
| RF-03 — Publicação de resenhas | FE-19, FE-22 | Completo (sem nome de autor) |
| RF-04 — Spoiler | FE-20, FE-21 | Completo |
| RF-05 — Chat em tempo real | FE-24, FE-25, FE-26 | Completo |
| RF-06 — Catálogo | FE-14, FE-15, FE-16 | Completo |
| RF-07 — Busca hiperlocal | FE-17, FE-18 | Completo |
| RF-08 — Checkout em até 3 passos | FE-30, FE-34, FE-39 | Completo |
| RF-09 — Compra em grupo | FE-30, FE-33, FE-34 | Completo |
| RF-10 / RD-02 — Mapa em tempo real | FE-27, FE-28, FE-29 | Completo |
| RF-11 / RF-12 — Pagamentos | FE-35, FE-36, FE-37, FE-38 | Completo (provedores simulados no servidor) |
| RF-13 — Ingresso com QR | FE-40 | **Bloqueado** — pendência de backend nº 1 |
| RF-14 / RNF-12 — Validação de ingresso | FE-41 | Completo |
| RF-15 — Combos | FE-33 | Completo |
| RF-16 — Compartilhamento | FE-23 | Completo |
| RF-17 — Notificações | FE-42, FE-43 | Registro completo; entrega não verificável |
| RNF-06 — Payload reduzido | FE-14, FE-48 | Completo |
| RNF-08 — Zero duplicidade | FE-30, FE-31, FE-32 | Garantido pelo servidor; o cliente não decide disponibilidade |
| Transversais | FE-03 a FE-08, FE-44 a FE-48 | Completo |
