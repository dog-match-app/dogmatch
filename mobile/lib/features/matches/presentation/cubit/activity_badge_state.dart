part of 'activity_badge_cubit.dart';

/// Parcelas do badge de atividade da aba Matches.
class ActivityBadgeState extends Equatable {
  const ActivityBadgeState({
    this.unreadMessages = 0,
    this.newMatches = 0,
    this.newLikes = 0,
  });

  /// Soma dos `unreadCount` de todos os matches.
  final int unreadMessages;

  /// Matches criados depois da última visita ao segmento "Matches".
  final int newMatches;

  /// Curtidas recebidas depois da última visita ao segmento "Curtidas".
  final int newLikes;

  /// Número exibido no badge da bottom bar.
  int get total => unreadMessages + newMatches + newLikes;

  @override
  List<Object?> get props => [unreadMessages, newMatches, newLikes];
}
