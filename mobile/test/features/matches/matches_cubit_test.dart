import 'dart:async';

import 'package:dogmatch/core/services/app_notifications_service.dart';
import 'package:dogmatch/core/services/realtime_service.dart';
import 'package:dogmatch/features/chat/data/models/message_model.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/domain/repositories/match_repository.dart';
import 'package:dogmatch/features/matches/presentation/cubit/matches_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMatchRepository extends Mock implements MatchRepository {}

class MockDogRepository extends Mock implements DogRepository {}

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

  MatchModel makeMatch(
    String id, {
    int unreadCount = 0,
    MessageModel? lastMessage,
  }) =>
      MatchModel(
        id: id,
        createdAt: DateTime.utc(2026, 3, 1),
        myDog: myDog,
        otherDog: otherDog,
        otherOwner:
            const MatchOwnerModel(id: 'owner-other', name: 'Tutora'),
        lastMessage: lastMessage,
        unreadCount: unreadCount,
      );

  late MockMatchRepository matchRepository;
  late MockDogRepository dogRepository;
  late ActiveDogCubit activeDogCubit;
  late MockRealtimeService realtimeService;
  late MockAppNotificationsService notificationsService;
  late StreamController<MatchModel> matchNewController;
  late StreamController<MessageModel> messageNewController;

  setUp(() {
    matchRepository = MockMatchRepository();
    dogRepository = MockDogRepository();
    realtimeService = MockRealtimeService();
    notificationsService = MockAppNotificationsService();
    matchNewController = StreamController<MatchModel>.broadcast();
    messageNewController = StreamController<MessageModel>.broadcast();
    when(() => realtimeService.onMatchNew)
        .thenAnswer((_) => matchNewController.stream);
    when(() => realtimeService.onMessageNew)
        .thenAnswer((_) => messageNewController.stream);
    when(() => notificationsService.isChatOpen(any())).thenReturn(false);
    when(() => dogRepository.getMyDogs()).thenAnswer((_) async => [myDog]);
    activeDogCubit = ActiveDogCubit(dogRepository);
  });

  tearDown(() async {
    await matchNewController.close();
    await messageNewController.close();
    await activeDogCubit.close();
  });

  MatchesCubit buildCubit() => MatchesCubit(
        matchRepository,
        activeDogCubit,
        realtimeService,
        notificationsService,
      );

  group('MatchesCubit', () {
    test('markRead zera o contador local do match sem refetch', () async {
      when(() => matchRepository.getMatches(dogId: myDog.id)).thenAnswer(
        (_) async => [makeMatch('m1', unreadCount: 3), makeMatch('m2')],
      );

      final cubit = buildCubit();
      await cubit.load();
      await pumpEventQueue();
      expect(cubit.state.matches.first.unreadCount, 3);

      cubit.markRead('m1');

      expect(cubit.state.matches.first.unreadCount, 0);
      expect(cubit.state.matches.last.id, 'm2');
      // Nenhum refetch: o GET /matches aconteceu só no load inicial.
      verify(() => matchRepository.getMatches(dogId: myDog.id)).called(1);
      await cubit.close();
    });

    test(
        'message:new com o chat fechado incrementa o unread local e '
        'atualiza a última mensagem', () async {
      when(() => matchRepository.getMatches(dogId: myDog.id))
          .thenAnswer((_) async => [makeMatch('m1')]);

      final cubit = buildCubit();
      await cubit.load();
      await pumpEventQueue();

      final message = MessageModel(
        id: 'msg-1',
        matchId: 'm1',
        senderId: 'owner-other',
        content: 'Oi! 🐶',
        createdAt: DateTime.utc(2026, 3, 2),
      );
      messageNewController.add(message);
      await pumpEventQueue();

      expect(cubit.state.matches.single.unreadCount, 1);
      expect(cubit.state.matches.single.lastMessage, message);
      await cubit.close();
    });

    test('message:new com o chat DAQUELE match aberto não incrementa',
        () async {
      when(() => matchRepository.getMatches(dogId: myDog.id))
          .thenAnswer((_) async => [makeMatch('m1')]);
      when(() => notificationsService.isChatOpen('m1')).thenReturn(true);

      final cubit = buildCubit();
      await cubit.load();
      await pumpEventQueue();

      messageNewController.add(
        MessageModel(
          id: 'msg-1',
          matchId: 'm1',
          senderId: 'owner-other',
          content: 'Oi!',
          createdAt: DateTime.utc(2026, 3, 2),
        ),
      );
      await pumpEventQueue();

      expect(cubit.state.matches.single.unreadCount, 0);
      await cubit.close();
    });

    test('match:new do cão ativo entra no topo da lista, com dedup',
        () async {
      when(() => matchRepository.getMatches(dogId: myDog.id))
          .thenAnswer((_) async => [makeMatch('m1')]);

      final cubit = buildCubit();
      await cubit.load();
      await pumpEventQueue();

      final incoming = makeMatch('m2');
      matchNewController.add(incoming);
      matchNewController.add(incoming);
      await pumpEventQueue();

      expect(
        cubit.state.matches.map((match) => match.id).toList(),
        ['m2', 'm1'],
      );
      await cubit.close();
    });
  });
}
