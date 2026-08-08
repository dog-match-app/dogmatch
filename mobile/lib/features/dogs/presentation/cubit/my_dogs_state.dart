part of 'my_dogs_cubit.dart';

enum MyDogsStatus { initial, loading, loaded, error }

class MyDogsState extends Equatable {
  const MyDogsState({
    this.status = MyDogsStatus.initial,
    this.dogs = const [],
    this.editingDog,
    this.saving = false,
    this.photoBusy = false,
    this.savedDog,
    this.deleted = false,
    this.errorMessage,
    this.successMessage,
  });

  final MyDogsStatus status;
  final List<DogModel> dogs;

  /// Cão em edição no formulário (atualizado após operações de foto).
  final DogModel? editingDog;

  final bool saving;

  /// Upload/remoção de foto em andamento.
  final bool photoBusy;

  /// Último cão criado/atualizado — consumido pelo listener do formulário.
  final DogModel? savedDog;

  /// O cão em edição foi excluído (o formulário deve fechar).
  final bool deleted;

  final String? errorMessage;
  final String? successMessage;

  MyDogsState copyWith({
    MyDogsStatus? status,
    List<DogModel>? dogs,
    DogModel? editingDog,
    bool? saving,
    bool? photoBusy,
    DogModel? savedDog,
    bool? deleted,
    String? errorMessage,
    String? successMessage,
  }) {
    return MyDogsState(
      status: status ?? this.status,
      dogs: dogs ?? this.dogs,
      editingDog: editingDog ?? this.editingDog,
      saving: saving ?? this.saving,
      photoBusy: photoBusy ?? this.photoBusy,
      savedDog: savedDog,
      deleted: deleted ?? this.deleted,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        dogs,
        editingDog,
        saving,
        photoBusy,
        savedDog,
        deleted,
        errorMessage,
        successMessage,
      ];
}
