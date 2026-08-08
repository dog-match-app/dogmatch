# CLAUDE.md — Mobile (Flutter)

App Flutter do DogMatch (Android/iOS): flutter_bloc + get_it/injectable + go_router +
dio + socket_io_client. O contrato da API (DTOs camelCase, endpoints, eventos WS) está
em `../ARCHITECTURE.md` — **fonte da verdade**: os models espelham os DTOs de lá,
NUNCA invente/renomeie campos.

## Comandos

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # após mudar models/DI
flutter analyze        # obrigatório: ZERO issues
flutter test           # obrigatório verde
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000   # emulador Android
```

SDK em `~/development/flutter` (stable), já no PATH. Celular físico: ver `README.md`.

## Invariantes (nunca violar)

1. **Camadas por feature**: `presentation → domain ← data`. `domain/` não importa
   `data/` nem Flutter (widgets). Widget NUNCA chama Dio/repository direto — sempre
   via cubit/bloc, que fala com o **contrato** de repository (`domain/repositories/`),
   implementado em `data/repositories/` com `@LazySingleton(as: Contrato)`.
2. **DI só via get_it/injectable**: dependências externas no `RegisterModule`
   (`app/di/`); cubits `@injectable`; obtenha via `getIt` / `BlocProvider`. Nunca
   instancie repository/cubit na mão dentro de widget. Anotou ⇒ rode build_runner.
3. **HTTP só pelo `DioClient` central** (interceptors de auth). Exceção única e
   intencional: `FileUploader` usa Dio limpo para o PUT presigned (request externa à
   API não pode levar bearer). Não crie novos Dio.
4. **Models**: json_serializable + `@JsonValue` nos enums (valores da API em
   MAIÚSCULO, ex.: `MALE`); labels PT-BR via extensions no `domain/`. Alterou model ⇒
   build_runner ⇒ commit dos `*.g.dart` junto.
5. **Navegação declarada apenas em `app/router/app_router.dart`** (go_router):
   novas telas = nova rota nomeada; navegue com `context.go/push('/rota')`; guards
   ficam no `redirect` central (que escuta o AuthBloc) — nunca trate auth em tela.
6. **Tema central** (`app/theme/`): cores via `Theme.of(context).colorScheme` /
   componentes do tema. Nunca `Color(0x...)` hardcoded em feature.
7. **UI em PT-BR**; código/identificadores em inglês; arquivos snake_case.
8. **Toda tela cobre 4 estados**: loading, erro (com retry), vazio (com CTA) e
   sucesso — use `LoadingIndicator`, `EmptyState`, `PrimaryButton` de `core/widgets/`.
9. Erros de rede: sempre convertidos por `ApiException` (`core/error/`) — cubits
   expõem `message` pronta em PT-BR para a UI; nunca mostre `DioException` cru.
10. Sem `print` (analyzer cobra); `debugPrint` só se realmente necessário.

## State management

- **Cubit** para estado de tela (padrão). **Bloc** (com events) apenas para fluxos
  orientados a eventos de várias origens — hoje, só o `AuthBloc` global.
- Estados imutáveis com Equatable: enum de status (`initial/loading/success/error`) +
  `copyWith` — siga os cubits existentes.
- Sessão: 401 irrecuperável flui `AuthInterceptor → AuthSessionManager → AuthBloc →
  redirect do router`. NUNCA trate expiração de sessão dentro de uma feature.
- `ActiveDogCubit` (lazySingleton) é a única fonte do "cão ativo" — Discovery e
  Matches escutam o mesmo; não duplique essa escolha em outro estado.

## Rede e tempo real

- `AuthInterceptor` faz refresh **single-flight** (Completer compartilhado; requests
  concorrentes aguardam o mesmo future; rotas `/auth/` não disparam refresh; flag
  anti-loop no retry). Não mexa sem preservar essas 4 propriedades.
- `SocketClient` (namespace `/chat`, `auth: {token}`): evento novo = documentar no
  ARCHITECTURE §3.7 + implementar no backend na mesma tarefa; trate reconexão
  (re-emitir `match:join`) e dedup por id.
- Upload de imagem: SEMPRE o fluxo presigned do `FileUploader`
  (`POST /files/presigned-upload` → PUT binário → registrar key/url na API).

## Padrões por feature (`lib/features/`)

### auth
- `AuthBloc` global (criado no `main.dart`): `AuthAppStarted` lê tokens → `GET /users/me`.
  Login/registro via `LoginCubit`/`RegisterCubit` → `AuthRepository` salva tokens e
  adiciona `AuthLoggedIn`. Telas de auth vivem FORA do shell de navegação.

### profile
- `ProfileCubit`: avatar via FileUploader (folder `avatars`); localização via
  geolocator com tratamento explícito de permissão negada/GPS off (SnackBar + não
  travar a tela). Logout sempre com dialog de confirmação → `AuthLogoutRequested`.

### dogs
- `MyDogsCubit` (CRUD). `DogFormPage`: enums com labels PT-BR (extensions), datePicker
  pt_BR, `birthDate` em ISO-8601 UTC. Fotos: máx **6** (espelha o backend), folder
  `dogs`, registrar com `POST /dogs/:id/photos {key}`; criar cão mantém o form aberto
  em modo edição (fotos precisam do id).

### dogs — página do cão (posts)
- Regras de tipo/limite centralizadas em `domain/entities/dog_post_rules.dart`
  (10 posts, texto 2000, legenda 200, 5 legendas/img, carrossel 2..8) — espelham o
  §3.5.2; mudou lá, muda aqui.
- Texto formatado SEMPRE via `TelegramText` (`core/utils/telegram_text.dart`);
  o dialog de ajuda de formatação do composer é obrigatório em novos campos com
  formatação. Erro `POST_LIMIT_REACHED` → `dogPostErrorMessage()` (PT-BR).
- Upload de imagem de post acontece NA SELEÇÃO (presigned via FileUploader);
  legendas guardam coordenadas normalizadas [0,1] clampadas.
- Redes sociais: cores de marca APENAS de `core/theme/social_brand.dart` (exceção
  documentada ao tema) e deep links APENAS via `buildSocialUrl()`
  (`core/utils/social_links.dart`) — nunca montar URL inline.

### discovery
- `DiscoveryCubit` + deck `flutter_card_swiper` (só horizontal). Swipe direita=LIKE,
  esquerda=PASS → `POST /swipes`; `matched:true` ⇒ dialog de match. Estados
  especiais obrigatórios: sem cães (CTA criar), `LOCATION_REQUIRED` (CTA perfil),
  deck vazio, erro+retry. Ao esgotar o deck, aguardar swipes pendentes antes de
  recarregar (evita repetir cards).

### search
- `SearchCubit`: debounce de 400ms no texto (Timer cancelável), paginação offset
  acumulada (`loadMore` a ~200px do fim; erro no loadMore preserva a lista com
  SnackBar — tela de erro cheia só com lista vazia), guarda contra resposta
  obsoleta (`_requestId`). `SearchFilters` (domain) é o value object dos filtros —
  filtro novo entra nele (`toQueryParams` + `activeCount`) + no `filter_sheet` +
  contrato §3.5.1. `dogId` (badges myAction/matched) vem do `ActiveDogCubit`;
  `excludeSwiped` NUNCA é enviado — mostrar tudo é o propósito da busca.
- `DogDetailPage` recebe `SearchCardModel` via `extra` com fallback `GET /dogs/:id`
  (`DogDetailCubit`); ações de swipe reutilizam `DiscoveryRepository.swipe` e o
  dialog de match do discovery — não duplique essa lógica.

### owners
- Perfil público do dono (`/owners/:id` ← card do dono no detalhe). `OwnersRepository`
  → `GET /users/:id/profile`; a resposta NUNCA tem email/telefone/coordenadas — não
  adicione esses campos ao model. Cards de cães navegam para `/search/dogs/:id`
  SEM extra (o detalhe busca via fallback).

### matches
- `MatchesCubit` refaz fetch quando o `ActiveDogCubit` troca (stream) e no
  pull-to-refresh. Sem lastMessage → placeholder "Vocês deram match! Diga oi 🐶".

### chat
- `ChatCubit` por conversa: histórico paginado por cursor (carrega mais no topo),
  envio via socket com fallback REST quando desconectado, `message:new` com dedup
  por id. AppBar mostra outro cão + dono.

## Padrões de UI obrigatórios (vindos de feedback do dono do produto)

- **Tags/chips**: SEMPRE via `DogTagChip`/`DogAgeChip`/`dogIntentChips()`
  (`features/dogs/presentation/widgets/dog_tag_chips.dart`) — ícone indica a
  categoria. Idade NUNCA aparece colada ao nome ("Rex, 2a" é proibido): é chip
  ("2 anos") ou item da grade de características.
- **Intenção**: "Ambos" é proibido na UI. BOTH rende DOIS chips (Cruzamento +
  Amizade) via `displayIntents`, ou o texto "Cruzamento e amizade" em campos únicos.
- **Características no detalhe**: grade rotulada (rótulo caixa alta + valor), nunca
  chips soltos sem categoria.
- **Datas digitáveis**: campos de data usam `BrDateInputFormatter` +
  `tryParseBrDate` (`core/utils/date_input.dart`) com máscara `dd/mm/aaaa` E botão
  de calendário escrevendo no MESMO controller — nunca só o picker.
- **Fotos**: qualquer imagem "hero" deve abrir no `PhotoViewerPage` (`/photo-viewer`
  com `PhotoViewerArgs`) — zoom por pinça e duplo-toque.

## Plataforma

- `minSdk = maxOf(23, flutter.minSdkVersion)` — não fixar valor menor (plugins exigem 23+).
- `usesCleartextTraffic` (Android) e ATS AllowsArbitraryLoads (iOS) são **dev-only**
  (API http local) — qualquer build de produção deve removê-los (comentários marcam).
- Permissão nova = AndroidManifest + Info.plist com usage description em PT-BR,
  sempre com fluxo de negado tratado na UI.

## Testes

- Padrão: `bloc_test` + `mocktail` mockando o contrato de repository — siga
  `test/features/auth/login_cubit_test.dart`. Todo cubit novo nasce com ao menos
  caso de sucesso + caso de falha (mensagem da ApiException).

## Checklist antes de concluir qualquer tarefa

build_runner rodado (se models/DI mudaram) · `flutter analyze` ZERO issues ·
`flutter test` verde · contrato do ARCHITECTURE respeitado · rotas só no router ·
4 estados de tela cobertos · strings de UI em PT-BR.
