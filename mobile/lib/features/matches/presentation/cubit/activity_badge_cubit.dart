import 'dart:async';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/services/app_notifications_service.dart';
import 'package:dogmatch/core/services/realtime_service.dart';
import 'package:dogmatch/core/storage/app_preferences.dart';
import 'package:dogmatch/features/chat/data/models/message_model.dart';
import 'package:dogmatch/features/matches/data/models/like_received_model.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/domain/repositories/likes_repository.dart';
import 'package:dogmatch/features/matches/domain/repositories/match_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'activity_badge_state.dart';

/// Contador de atividade da aba Matches para o badge da bottom bar:
/// mensagens não lidas (soma dos `unreadCount`) + matches novos + curtidas
/// novas desde a última visita a cada segmento (`lastSeen` persistido no
/// `AppPreferences`).
///
/// Vive a sessão inteira ([start] no `AuthAuthenticated`, [reset] no
/// `SessionReset`) e conta TODOS os meus cães (fetch sem `dogId`): o badge
/// avisa que algo aconteceu, a aba filtra pelo cão ativo. Atualizações:
/// snapshot inicial via REST + incrementos pelos eventos do socket
/// (`match:new`, `message:new`) + zeragens pelas telas ([markMatchesSeen]/
/// [markLikesSeen] ao abrir cada segmento; chat aberto via stream
/// `onChatOpened` do `AppNotificationsService` — sem acoplamento com o
/// `ChatCubit`).
///
/// Também é quem dispara as notificações do SO: recebeu o evento, atualiza
/// o contador e aciona o `AppNotificationsService` (que decide suprimir
/// por tela ativa). A de match sai com um pequeno atraso: no like que fecha
/// o match, o `match:new` chega ANTES da resposta do `POST /swipes`, e o
/// atraso dá tempo do MatchDialog se registrar e suprimir o aviso duplicado.
@lazySingleton
class ActivityBadgeCubit extends Cubit<ActivityBadgeState> {
  ActivityBadgeCubit(
    this._matchRepository,
    this._likesRepository,
    this._appPreferences,
    this._realtimeService,
    this._notificationsService,
  ) : super(const ActivityBadgeState());

  final MatchRepository _matchRepository;
  final LikesRepository _likesRepository;
  final AppPreferences _appPreferences;
  final RealtimeService _realtimeService;
  final AppNotificationsService _notificationsService;

  /// Janela para o MatchDialog do próprio swipe se registrar antes da
  /// notificação de `match:new` (zerada nos testes).
  @visibleForTesting
  Duration matchNotifyDelay = const Duration(milliseconds: 1500);

  final Map<String, MatchModel> _matchesById = {};
  final Map<String, LikeReceivedModel> _likesByDogId = {};

  DateTime? _lastSeenMatches;
  DateTime? _lastSeenLikes;

  StreamSubscription<MatchModel>? _matchNewSubscription;
  StreamSubscription<MessageModel>? _messageNewSubscription;
  StreamSubscription<String>? _chatOpenedSubscription;

  bool _started = false;

  /// Início da sessão autenticada: escuta o socket e carrega o snapshot.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _matchNewSubscription = _realtimeService.onMatchNew.listen(_onMatchNew);
    _messageNewSubscription =
        _realtimeService.onMessageNew.listen(_onMessageNew);
    _chatOpenedSubscription =
        _notificationsService.onChatOpened.listen(_onChatOpened);
    await refresh();
  }

  /// Recarrega o snapshot (matches + curtidas de todos os meus cães).
  /// Cada parte é melhor-esforço: um erro mantém os dados que já existem —
  /// o badge nunca derruba nada.
  Future<void> refresh() async {
    try {
      _lastSeenMatches = await _appPreferences.getLastSeenMatches();
      _lastSeenLikes = await _appPreferences.getLastSeenLikes();
    } on Exception {
      // Preferência ilegível conta tudo como novo — melhor avisar demais.
    }
    await _refreshMatches();
    try {
      final likes = await _likesRepository.getReceived();
      if (isClosed || !_started) return;
      _likesByDogId
        ..clear()
        ..addEntries(likes.items.map((like) => MapEntry(like.dog.id, like)));
    } on ApiException {
      // Sem curtidas atualizadas, a parcela fica como está.
    }
    _recompute();
  }

  /// Visita ao segmento "Matches": os matches atuais deixam de ser "novos".
  Future<void> markMatchesSeen() async {
    final now = DateTime.now().toUtc();
    _lastSeenMatches = now;
    _recompute();
    try {
      await _appPreferences.setLastSeenMatches(now);
    } on Exception {
      // Sem persistir, o valor ainda vale nesta sessão.
    }
  }

  /// Visita ao segmento "Curtidas": as curtidas atuais deixam de ser "novas".
  Future<void> markLikesSeen() async {
    final now = DateTime.now().toUtc();
    _lastSeenLikes = now;
    _recompute();
    try {
      await _appPreferences.setLastSeenLikes(now);
    } on Exception {
      // Idem.
    }
  }

  /// Fim de sessão (logout/expiração), chamado pelo `SessionReset`.
  void reset() {
    _started = false;
    unawaited(_matchNewSubscription?.cancel());
    unawaited(_messageNewSubscription?.cancel());
    unawaited(_chatOpenedSubscription?.cancel());
    _matchNewSubscription = null;
    _messageNewSubscription = null;
    _chatOpenedSubscription = null;
    _matchesById.clear();
    _likesByDogId.clear();
    _lastSeenMatches = null;
    _lastSeenLikes = null;
    emit(const ActivityBadgeState());
  }

  void _onMatchNew(MatchModel match) {
    _matchesById[match.id] = match;
    // O like que virou match sai das curtidas pendentes (o backend também
    // o remove de GET /swipes/received).
    _likesByDogId.remove(match.otherDog.id);
    _recompute();
    unawaited(_notifyMatchLater(match));
  }

  Future<void> _notifyMatchLater(MatchModel match) async {
    await Future<void>.delayed(matchNotifyDelay);
    if (isClosed || !_started) return;
    await _notificationsService.showMatch(match);
  }

  void _onMessageNew(MessageModel message) {
    // Chat do match aberto: o ChatCubit está tratando (exibe e marca como
    // lida) — nem contador, nem notificação.
    if (_notificationsService.isChatOpen(message.matchId)) return;
    final match = _matchesById[message.matchId];
    if (match != null) {
      _matchesById[message.matchId] =
          match.copyWith(unreadCount: match.unreadCount + 1);
      _recompute();
    } else {
      // Match desconhecido (evento `match:new` perdido): re-sincroniza.
      unawaited(_refreshMatchesAndRecompute());
    }
    unawaited(_notificationsService.showMessage(message, match: match));
  }

  void _onChatOpened(String matchId) {
    final match = _matchesById[matchId];
    if (match == null || match.unreadCount == 0) return;
    _matchesById[matchId] = match.copyWith(unreadCount: 0);
    _recompute();
  }

  Future<void> _refreshMatches() async {
    try {
      final matches = await _matchRepository.getMatches();
      if (isClosed || !_started) return;
      _matchesById
        ..clear()
        ..addEntries(matches.map((match) => MapEntry(match.id, match)));
    } on ApiException {
      // Sem matches atualizados, a parcela fica como está.
    }
  }

  Future<void> _refreshMatchesAndRecompute() async {
    await _refreshMatches();
    _recompute();
  }

  void _recompute() {
    if (isClosed) return;
    final lastSeenMatches = _lastSeenMatches;
    final lastSeenLikes = _lastSeenLikes;
    var unreadMessages = 0;
    var newMatches = 0;
    for (final match in _matchesById.values) {
      unreadMessages += match.unreadCount;
      if (lastSeenMatches == null || match.createdAt.isAfter(lastSeenMatches)) {
        newMatches++;
      }
    }
    final newLikes = _likesByDogId.values
        .where(
          (like) =>
              lastSeenLikes == null || like.likedAt.isAfter(lastSeenLikes),
        )
        .length;
    emit(
      ActivityBadgeState(
        unreadMessages: unreadMessages,
        newMatches: newMatches,
        newLikes: newLikes,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _matchNewSubscription?.cancel();
    await _messageNewSubscription?.cancel();
    await _chatOpenedSubscription?.cancel();
    return super.close();
  }
}
