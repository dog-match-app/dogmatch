import 'dart:async';

import 'package:dogmatch/core/services/app_notifications_service.dart';
import 'package:dogmatch/core/services/realtime_service.dart';
import 'package:dogmatch/core/storage/app_preferences.dart';
import 'package:dogmatch/features/chat/data/models/message_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_owner_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/matches/data/models/like_received_model.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/domain/repositories/likes_repository.dart';
import 'package:dogmatch/features/matches/domain/repositories/match_repository.dart';
import 'package:dogmatch/features/matches/presentation/cubit/activity_badge_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMatchRepository extends Mock implements MatchRepository {}

class MockLikesRepository extends Mock implements LikesRepository {}

class MockAppPreferences extends Mock implements AppPreferences {}

class MockRealtimeService extends Mock implements RealtimeService {}

class MockAppNotificationsService extends Mock
    implements AppNotificationsService {}

DogModel _makeDog(String id, {String name = 'Rex'}) => DogModel(
      id: id,
      ownerId: 'owner-$id',
      name: name,
      breed: 'Vira-lata',
      sex: DogSex.male,
      birthDate: DateTime.utc(2024),
      size: DogSize.medium,
      intent: DogIntent.friendship,
      createdAt: DateTime.utc(2026),
    );

void main() {
  final myDog = _makeDog('my-dog', name: 'Bidu');
  final otherDog = _makeDog('other-dog', name: 'Luna');
  final likerDog = _makeDog('liker-dog', name: 'Thor');

  // Última visita aos segmentos: 10/01. Só o que veio DEPOIS conta como novo.
  final lastSeen = DateTime.utc(2026, 1, 10);

  MatchModel makeMatch(String id, DateTime createdAt, {int unreadCount = 0}) =>
      MatchModel(
        id: id,
        createdAt: createdAt,
        myDog: myDog,
        otherDog: otherDog,
        otherOwner:
            const MatchOwnerModel(id: 'owner-other', name: 'Tutora'),
        unreadCount: unreadCount,
      );

  LikeReceivedModel makeLike(DogModel dog, DateTime likedAt) =>
      LikeReceivedModel(
        dog: dog,
        owner: DogOwnerModel(id: 'owner-${dog.id}', name: 'Tutora'),
        likedAt: likedAt,
      );

  // Match antigo (não conta como novo) com 2 não lidas; match novo com 1.
  final oldMatch =
      makeMatch('m-old', DateTime.utc(2026, 1, 5), unreadCount: 2);
  final newMatch =
      makeMatch('m-new', DateTime.utc(2026, 1, 15), unreadCount: 1);
  // Curtida nova (conta) e curtida antiga (não conta).
  final newLike = makeLike(likerDog, DateTime.utc(2026, 1, 20));
  final oldLike = makeLike(otherDog, DateTime.utc(2026, 1, 2));

  late MockMatchRepository matchRepository;
  late MockLikesRepository likesRepository;
  late MockAppPreferences appPreferences;
  late MockRealtimeService realtimeService;
  late MockAppNotificationsService notificationsService;
  late StreamController<MatchModel> matchNewController;
  late StreamController<MessageModel> messageNewController;
  late StreamController<String> chatOpenedController;

  setUpAll(() {
    registerFallbackValue(makeMatch('fallback', DateTime.utc(2026)));
    registerFallbackValue(
      MessageModel(
        id: 'fallback',
        matchId: 'fallback',
        senderId: 'fallback',
        content: '',
        createdAt: DateTime.utc(2026),
      ),
    );
    registerFallbackValue(DateTime.utc(2026));
  });

  setUp(() {
    matchRepository = MockMatchRepository();
    likesRepository = MockLikesRepository();
    appPreferences = MockAppPreferences();
    realtimeService = MockRealtimeService();
    notificationsService = MockAppNotificationsService();
    matchNewController = StreamController<MatchModel>.broadcast();
    messageNewController = StreamController<MessageModel>.broadcast();
    chatOpenedController = StreamController<String>.broadcast();

    when(() => realtimeService.onMatchNew)
        .thenAnswer((_) => matchNewController.stream);
    when(() => realtimeService.onMessageNew)
        .thenAnswer((_) => messageNewController.stream);
    when(() => notificationsService.onChatOpened)
        .thenAnswer((_) => chatOpenedController.stream);
    when(() => notificationsService.isChatOpen(any())).thenReturn(false);
    when(() => notificationsService.showMatch(any()))
        .thenAnswer((_) async {});
    when(
      () => notificationsService.showMessage(
        any(),
        match: any(named: 'match'),
      ),
    ).thenAnswer((_) async {});
    when(() => appPreferences.getLastSeenMatches())
        .thenAnswer((_) async => lastSeen);
    when(() => appPreferences.getLastSeenLikes())
        .thenAnswer((_) async => lastSeen);
    when(() => appPreferences.setLastSeenMatches(any()))
        .thenAnswer((_) async {});
    when(() => appPreferences.setLastSeenLikes(any()))
        .thenAnswer((_) async {});
    // Fetch sem dogId: o badge conta a atividade de TODOS os meus cães.
    when(() => matchRepository.getMatches())
        .thenAnswer((_) async => [oldMatch, newMatch]);
    when(() => likesRepository.getReceived()).thenAnswer(
      (_) async => LikesReceivedModel(items: [newLike, oldLike], total: 2),
    );
  });

  tearDown(() async {
    await matchNewController.close();
    await messageNewController.close();
    await chatOpenedController.close();
  });

  ActivityBadgeCubit buildCubit() => ActivityBadgeCubit(
        matchRepository,
        likesRepository,
        appPreferences,
        realtimeService,
        notificationsService,
      )..matchNotifyDelay = Duration.zero;

  group('ActivityBadgeCubit', () {
    test(
        'start soma não lidas + matches novos + curtidas novas em relação '
        'ao lastSeen persistido', () async {
      final cubit = buildCubit();
      await cubit.start();
      await pumpEventQueue();

      expect(
        cubit.state,
        const ActivityBadgeState(
          unreadMessages: 3,
          newMatches: 1,
          newLikes: 1,
        ),
      );
      expect(cubit.state.total, 5);
      await cubit.close();
    });

    test('abrir o segmento Matches zera a parcela de novos e persiste',
        () async {
      final cubit = buildCubit();
      await cubit.start();
      await pumpEventQueue();

      await cubit.markMatchesSeen();

      expect(cubit.state.newMatches, 0);
      expect(cubit.state.total, 4);
      verify(() => appPreferences.setLastSeenMatches(any())).called(1);
      await cubit.close();
    });

    test('abrir o segmento Curtidas zera a parcela de novas e persiste',
        () async {
      final cubit = buildCubit();
      await cubit.start();
      await pumpEventQueue();

      await cubit.markLikesSeen();

      expect(cubit.state.newLikes, 0);
      expect(cubit.state.total, 4);
      verify(() => appPreferences.setLastSeenLikes(any())).called(1);
      await cubit.close();
    });

    test(
        'message:new com chat fechado incrementa as não lidas; abrir o '
        'chat (onChatOpened) zera as daquele match', () async {
      final cubit = buildCubit();
      await cubit.start();
      await pumpEventQueue();

      messageNewController.add(
        MessageModel(
          id: 'msg-1',
          matchId: 'm-old',
          senderId: 'owner-other',
          content: 'Oi!',
          createdAt: DateTime.utc(2026, 3, 2),
        ),
      );
      await pumpEventQueue();
      expect(cubit.state.unreadMessages, 4);

      chatOpenedController.add('m-old');
      await pumpEventQueue();
      // Zeradas as 3 do match aberto; sobra a não lida do outro match.
      expect(cubit.state.unreadMessages, 1);
      await cubit.close();
    });

    test(
        'match:new soma um match novo e tira o cão da parcela de curtidas '
        '(o like virou match)', () async {
      final cubit = buildCubit();
      await cubit.start();
      await pumpEventQueue();
      expect(cubit.state.newLikes, 1);

      matchNewController.add(
        MatchModel(
          id: 'm-from-like',
          createdAt: DateTime.utc(2026, 3, 10),
          myDog: myDog,
          otherDog: likerDog,
          otherOwner:
              const MatchOwnerModel(id: 'owner-liker', name: 'Tutora'),
        ),
      );
      await pumpEventQueue();

      expect(cubit.state.newMatches, 2);
      expect(cubit.state.newLikes, 0);
      await cubit.close();
    });
  });
}
