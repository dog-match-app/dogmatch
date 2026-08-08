import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Seleção (em memória) do cão com o qual o usuário está "jogando".
/// Compartilhada entre Discovery (dropdown) e Matches (filtro da lista).
@lazySingleton
class ActiveDogCubit extends Cubit<DogModel?> {
  ActiveDogCubit() : super(null);

  void select(DogModel? dog) => emit(dog);
}
