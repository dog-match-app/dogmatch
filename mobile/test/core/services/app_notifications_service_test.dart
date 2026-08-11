import 'package:dogmatch/core/services/app_notifications_service.dart';
import 'package:dogmatch/features/chat/data/models/message_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsGateway extends Mock implements NotificationsGateway {}

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

MessageModel _makeMessage(String matchId, {String content = 'Oi! 🐶'}) =>
    MessageModel(
      id: 'msg-$matchId',
      matchId: matchId,
      senderId: 'sender-1',
      content: content,
      createdAt: DateTime.utc(2026, 3, 1),
    );

void main() {
  final match = MatchModel(
    id: 'match-1',
    createdAt: DateTime.utc(2026, 3, 1),
    myDog: _makeDog('my-dog', name: 'Bidu'),
    otherDog: _makeDog('other-dog', name: 'Luna'),
    otherOwner: const MatchOwnerModel(id: 'owner-2', name: 'Tutora'),
  );

  late MockNotificationsGateway gateway;
  late AppNotificationsService service;

  setUpAll(() {
    registerFallbackValue(AppNotificationChannel.messages);
  });

  setUp(() {
    gateway = MockNotificationsGateway();
    when(() => gateway.initialize()).thenAnswer((_) async {});
    when(() => gateway.requestPermission()).thenAnswer((_) async => true);
    when(
      () => gateway.show(
        id: any(named: 'id'),
        channel: any(named: 'channel'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});
    service = AppNotificationsService(gateway);
  });

  group('AppNotificationsService — mensagens', () {
    test('notifica message:new com o chat daquele match FECHADO', () async {
      await service.showMessage(_makeMessage('match-1'), match: match);

      verify(
        () => gateway.show(
          id: any(named: 'id'),
          channel: AppNotificationChannel.messages,
          title: 'Luna · Tutora',
          body: 'Oi! 🐶',
        ),
      ).called(1);
    });

    test('NÃO notifica com o chat daquele match ABERTO', () async {
      service.chatOpened('match-1');

      await service.showMessage(_makeMessage('match-1'), match: match);

      verifyNever(
        () => gateway.show(
          id: any(named: 'id'),
          channel: any(named: 'channel'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      );
    });

    test('chat aberto de OUTRO match não suprime a notificação', () async {
      service.chatOpened('match-2');

      await service.showMessage(_makeMessage('match-1'), match: match);

      verify(
        () => gateway.show(
          id: any(named: 'id'),
          channel: AppNotificationChannel.messages,
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).called(1);
    });

    test('fechar o chat volta a notificar', () async {
      service.chatOpened('match-1');
      service.chatClosed('match-1');

      await service.showMessage(_makeMessage('match-1'), match: match);

      verify(
        () => gateway.show(
          id: any(named: 'id'),
          channel: AppNotificationChannel.messages,
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).called(1);
    });

    test('sem match conhecido usa o título genérico', () async {
      await service.showMessage(_makeMessage('match-9'));

      verify(
        () => gateway.show(
          id: any(named: 'id'),
          channel: AppNotificationChannel.messages,
          title: 'Nova mensagem',
          body: any(named: 'body'),
        ),
      ).called(1);
    });
  });

  group('AppNotificationsService — matches', () {
    test('notifica match:new uma única vez por match', () async {
      await service.showMatch(match);
      await service.showMatch(match);

      verify(
        () => gateway.show(
          id: any(named: 'id'),
          channel: AppNotificationChannel.matches,
          title: 'Deu match! 🐾',
          body: 'Bidu e Luna se curtiram!',
        ),
      ).called(1);
    });

    test('NÃO notifica um match cujo MatchDialog foi mostrado', () async {
      service.matchDialogShown('match-1');

      await service.showMatch(match);

      verifyNever(
        () => gateway.show(
          id: any(named: 'id'),
          channel: any(named: 'channel'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      );
    });
  });

  group('AppNotificationsService — permissão por sessão', () {
    test('pede uma única vez por sessão; resetSession libera de novo',
        () async {
      await service.requestPermissionAtSessionStart();
      await service.requestPermissionAtSessionStart();
      verify(() => gateway.requestPermission()).called(1);

      service.resetSession();
      await service.requestPermissionAtSessionStart();
      verify(() => gateway.requestPermission()).called(1);
    });
  });
}
