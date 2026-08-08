part of 'matches_cubit.dart';

enum MatchesStatus { initial, loading, loaded, error }

class MatchesState extends Equatable {
  const MatchesState({
    this.status = MatchesStatus.initial,
    this.matches = const [],
    this.activeDogId,
    this.errorMessage,
  });

  final MatchesStatus status;
  final List<MatchModel> matches;
  final String? activeDogId;
  final String? errorMessage;

  MatchesState copyWith({
    MatchesStatus? status,
    List<MatchModel>? matches,
    String? activeDogId,
    String? errorMessage,
  }) {
    return MatchesState(
      status: status ?? this.status,
      matches: matches ?? this.matches,
      activeDogId: activeDogId ?? this.activeDogId,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, matches, activeDogId, errorMessage];
}
