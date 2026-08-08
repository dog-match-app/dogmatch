part of 'discovery_cubit.dart';

enum DiscoveryStatus {
  initial,
  loading,
  loaded,
  noDogs,
  locationRequired,
  error,
}

class DiscoveryState extends Equatable {
  const DiscoveryState({
    this.status = DiscoveryStatus.initial,
    this.myDogs = const [],
    this.activeDog,
    this.cards = const [],
    this.deckKey = 0,
    this.pendingMatch,
    this.errorMessage,
    this.swipeError,
  });

  final DiscoveryStatus status;
  final List<DogModel> myDogs;
  final DogModel? activeDog;
  final List<DiscoveryCardModel> cards;

  /// Incrementado a cada novo deck para recriar o CardSwiper.
  final int deckKey;

  /// Match recém-criado aguardando o dialog "Deu match!".
  final MatchModel? pendingMatch;

  final String? errorMessage;

  /// Erro transitório ao registrar um swipe (SnackBar).
  final String? swipeError;

  DiscoveryState copyWith({
    DiscoveryStatus? status,
    List<DogModel>? myDogs,
    DogModel? activeDog,
    List<DiscoveryCardModel>? cards,
    int? deckKey,
    MatchModel? pendingMatch,
    String? errorMessage,
    String? swipeError,
  }) {
    return DiscoveryState(
      status: status ?? this.status,
      myDogs: myDogs ?? this.myDogs,
      activeDog: activeDog ?? this.activeDog,
      cards: cards ?? this.cards,
      deckKey: deckKey ?? this.deckKey,
      pendingMatch: pendingMatch,
      errorMessage: errorMessage,
      swipeError: swipeError,
    );
  }

  @override
  List<Object?> get props => [
        status,
        myDogs,
        activeDog,
        cards,
        deckKey,
        pendingMatch,
        errorMessage,
        swipeError,
      ];
}
