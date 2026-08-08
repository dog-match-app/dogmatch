part of 'dog_detail_cubit.dart';

enum DogDetailStatus { initial, loading, success, error }

class DogDetailState extends Equatable {
  const DogDetailState({
    this.status = DogDetailStatus.initial,
    this.card,
    this.activeDog,
    this.actionInProgress = false,
    this.message,
    this.actionError,
    this.pendingMatch,
    this.matchToOpen,
  });

  final DogDetailStatus status;

  /// Card exibido (via extra da rota ou montado do `GET /dogs/:id`).
  final SearchCardModel? card;

  /// Cão ativo usado nas ações; `null` = usuário sem cães (esconde ações).
  final DogModel? activeDog;

  /// Like/pass ou busca do match em andamento (desabilita os botões).
  final bool actionInProgress;

  /// Erro do carregamento da página (estado de erro com retry).
  final String? message;

  /// One-shot: erro transitório de uma ação (SnackBar).
  final String? actionError;

  /// One-shot: match recém-criado aguardando o dialog "Deu match! 🐾".
  final MatchModel? pendingMatch;

  /// One-shot: match a abrir no chat.
  final MatchModel? matchToOpen;

  DogDetailState copyWith({
    DogDetailStatus? status,
    SearchCardModel? card,
    DogModel? activeDog,
    bool? actionInProgress,
    String? message,
    String? actionError,
    MatchModel? pendingMatch,
    MatchModel? matchToOpen,
  }) {
    return DogDetailState(
      status: status ?? this.status,
      card: card ?? this.card,
      activeDog: activeDog ?? this.activeDog,
      actionInProgress: actionInProgress ?? this.actionInProgress,
      message: message,
      actionError: actionError,
      pendingMatch: pendingMatch,
      matchToOpen: matchToOpen,
    );
  }

  @override
  List<Object?> get props => [
        status,
        card,
        activeDog,
        actionInProgress,
        message,
        actionError,
        pendingMatch,
        matchToOpen,
      ];
}
