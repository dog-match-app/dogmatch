part of 'active_dog_cubit.dart';

enum ActiveDogStatus { initial, loading, ready, error }

class ActiveDogState extends Equatable {
  const ActiveDogState({
    this.status = ActiveDogStatus.initial,
    this.dogs = const [],
    this.active,
    this.message,
  });

  final ActiveDogStatus status;
  final List<DogModel> dogs;

  /// Cão selecionado; `null` só quando o usuário ainda não tem cães.
  final DogModel? active;

  final String? message;

  bool get hasDogs => dogs.isNotEmpty;

  /// Com um único cão não há o que trocar — a UI mostra só o nome.
  bool get canSwitch => dogs.length > 1;

  ActiveDogState copyWith({
    ActiveDogStatus? status,
    List<DogModel>? dogs,
    DogModel? active,
    String? message,
  }) {
    return ActiveDogState(
      status: status ?? this.status,
      dogs: dogs ?? this.dogs,
      active: active ?? this.active,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, dogs, active, message];
}
