part of 'likes_cubit.dart';

enum LikesStatus { initial, loading, loaded, error }

class LikesState extends Equatable {
  const LikesState({
    this.status = LikesStatus.initial,
    this.likes = const [],
    this.activeDogId,
    this.likingBackDogIds = const {},
    this.errorMessage,
    this.pendingMatch,
    this.actionError,
  });

  final LikesStatus status;
  final List<LikeReceivedModel> likes;
  final String? activeDogId;

  /// Cães com "Curtir de volta" em andamento (desabilita o botão do card).
  final Set<String> likingBackDogIds;

  final String? errorMessage;

  /// Match recém-criado pelo "Curtir de volta", aguardando o MatchDialog.
  final MatchModel? pendingMatch;

  /// Erro transitório do "Curtir de volta" (SnackBar).
  final String? actionError;

  LikesState copyWith({
    LikesStatus? status,
    List<LikeReceivedModel>? likes,
    String? activeDogId,
    Set<String>? likingBackDogIds,
    String? errorMessage,
    MatchModel? pendingMatch,
    String? actionError,
  }) {
    return LikesState(
      status: status ?? this.status,
      likes: likes ?? this.likes,
      activeDogId: activeDogId ?? this.activeDogId,
      likingBackDogIds: likingBackDogIds ?? this.likingBackDogIds,
      errorMessage: errorMessage,
      pendingMatch: pendingMatch,
      actionError: actionError,
    );
  }

  @override
  List<Object?> get props => [
        status,
        likes,
        activeDogId,
        likingBackDogIds,
        errorMessage,
        pendingMatch,
        actionError,
      ];
}
