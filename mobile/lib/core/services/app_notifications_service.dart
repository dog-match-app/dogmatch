import 'dart:async';

import 'package:dogmatch/features/chat/data/models/message_model.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

/// Canais de notificação local. O `id` é estável (contrato com o SO); nome e
/// descrição aparecem nas configurações do sistema, por isso em PT-BR.
enum AppNotificationChannel {
  matches(
    id: 'matches',
    name: 'Novos matches',
    description: 'Avisos quando dois cães se curtem.',
  ),
  messages(
    id: 'messages',
    name: 'Mensagens',
    description: 'Novas mensagens das suas conversas.',
  );

  const AppNotificationChannel({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

/// Porta fina sobre o `flutter_local_notifications` para os testes mockarem
/// sem tocar no plugin (mesmo padrão do `LocationGateway`).
abstract class NotificationsGateway {
  Future<void> initialize();

  /// Pede a permissão de notificações em runtime (Android 13+ / iOS).
  Future<bool> requestPermission();

  Future<void> show({
    required int id,
    required AppNotificationChannel channel,
    required String title,
    required String body,
  });
}

@LazySingleton(as: NotificationsGateway)
class FlutterLocalNotificationsGateway implements NotificationsGateway {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize() async {
    // Permissões do iOS NÃO são pedidas aqui: o pedido acontece uma vez por
    // sessão no shell, sequenciado após o fluxo de localização.
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<void> show({
    required int id,
    required AppNotificationChannel channel,
    required String title,
    required String body,
  }) {
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}

/// Notificações locais do app (novos matches e mensagens via socket) + o
/// registro de "tela ativa" que decide quando NÃO notificar.
///
/// Regras de supressão:
/// - mensagem: nada de notificação com o chat DAQUELE match aberto
///   ([chatOpened]/[chatClosed], alimentados pelo `ChatCubit`);
/// - match: nada de notificação quando o MatchDialog daquele match foi
///   mostrado nesta sessão ([matchDialogShown], chamado pelas páginas logo
///   antes do `showDialog`) — o registro é permanente na sessão para o
///   evento `match:new` atrasado não repetir um match já celebrado na tela.
///
/// Limitação conhecida e aceita: tudo aqui depende do socket, então com o
/// app morto não há notificação (push real é roadmap/FCM).
@lazySingleton
class AppNotificationsService {
  AppNotificationsService(this._gateway);

  final NotificationsGateway _gateway;

  final Set<String> _openChatMatchIds = {};
  final Set<String> _handledMatchIds = {};
  final StreamController<String> _chatOpenedController =
      StreamController<String>.broadcast();

  bool _initialized = false;
  bool _permissionRequestedThisSession = false;

  /// Emite o `matchId` sempre que um chat abre — o `ActivityBadgeCubit`
  /// escuta para zerar as não lidas daquele match sem acoplar cubits.
  Stream<String> get onChatOpened => _chatOpenedController.stream;

  bool isChatOpen(String matchId) => _openChatMatchIds.contains(matchId);

  /// Chat do match aberto: suprime notificações de mensagem dele.
  void chatOpened(String matchId) {
    _openChatMatchIds.add(matchId);
    _chatOpenedController.add(matchId);
  }

  void chatClosed(String matchId) {
    _openChatMatchIds.remove(matchId);
  }

  /// MatchDialog do match exibido em tela: suprime a notificação dele.
  void matchDialogShown(String matchId) {
    _handledMatchIds.add(matchId);
  }

  /// Pedido único por sessão (chamado pelo shell APÓS o fluxo de
  /// localização — os dialogs de permissão nunca se empilham).
  Future<void> requestPermissionAtSessionStart() async {
    if (_permissionRequestedThisSession) return;
    _permissionRequestedThisSession = true;
    if (!await _ensureInitialized()) return;
    try {
      await _gateway.requestPermission();
    } on Exception {
      // Sem permissão o app segue normal — só não notifica.
    }
  }

  /// Notifica um novo match (`match:new`), exceto se o dialog dele já
  /// apareceu nesta sessão.
  Future<void> showMatch(MatchModel match) async {
    if (!_handledMatchIds.add(match.id)) return;
    if (!await _ensureInitialized()) return;
    try {
      await _gateway.show(
        id: _notificationId(match.id, _matchIdSpace),
        channel: AppNotificationChannel.matches,
        title: 'Deu match! 🐾',
        body: '${match.myDog.name} e ${match.otherDog.name} se curtiram!',
      );
    } on Exception {
      // Falha do plugin nunca pode derrubar o fluxo que notifica.
    }
  }

  /// Notifica uma mensagem nova (`message:new`), exceto com o chat daquele
  /// match aberto. [match] enriquece o título quando conhecido.
  Future<void> showMessage(MessageModel message, {MatchModel? match}) async {
    if (isChatOpen(message.matchId)) return;
    if (!await _ensureInitialized()) return;
    final title = match == null
        ? 'Nova mensagem'
        : '${match.otherDog.name} · ${match.otherOwner.name}';
    try {
      await _gateway.show(
        // Id estável por match: a mensagem mais nova substitui a anterior
        // da mesma conversa em vez de empilhar.
        id: _notificationId(message.matchId, _messageIdSpace),
        channel: AppNotificationChannel.messages,
        title: title,
        body: message.content,
      );
    } on Exception {
      // Idem: melhor esforço.
    }
  }

  /// Fim de sessão (logout/expiração), chamado pelo `SessionReset`.
  void resetSession() {
    _permissionRequestedThisSession = false;
    _openChatMatchIds.clear();
    _handledMatchIds.clear();
  }

  /// Espaços disjuntos para os ids numéricos (o id do plugin é global, não
  /// por canal): bit alto distingue match de mensagem.
  static const int _messageIdSpace = 0;
  static const int _matchIdSpace = 0x40000000;

  int _notificationId(String key, int space) =>
      (key.hashCode & 0x3FFFFFFF) | space;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      await _gateway.initialize();
      _initialized = true;
    } on Exception {
      // Plugin indisponível (ex.: plataforma sem suporte): segue sem
      // notificações, tentando de novo no próximo uso.
    }
    return _initialized;
  }

  @disposeMethod
  void dispose() {
    unawaited(_chatOpenedController.close());
  }
}
