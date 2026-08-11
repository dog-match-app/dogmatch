import 'dart:async';

import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDogRepository extends Mock implements DogRepository {}

DogModel _makeDog(String id, {String name = 'Rex'}) => DogModel(
      id: id,
      ownerId: 'owner-$id',
      name: name,
      breed: 'Vira-lata',
      sex: DogSex.male,
      birthDate: DateTime.utc(2024),
      size: DogSize.medium,
      intent: DogIntent.friendship,
      createdAt: DateTime.utc(2026),
    );

void main() {
  final previousAccountDog = _makeDog('dog-conta-antiga', name: 'Bidu');
  final newAccountDog = _makeDog('dog-conta-nova', name: 'Luna');

  late MockDogRepository dogRepository;
  late ActiveDogCubit cubit;

  setUp(() {
    dogRepository = MockDogRepository();
    cubit = ActiveDogCubit(dogRepository);
  });

  tearDown(() => cubit.close());

  group('ActiveDogCubit.reset — troca de conta', () {
    test(
        'após o reset, nada da conta anterior vaza e o próximo ensureLoaded '
        'recarrega para a conta nova', () async {
      when(() => dogRepository.getMyDogs())
          .thenAnswer((_) async => [previousAccountDog]);
      await cubit.ensureLoaded();
      expect(cubit.state.status, ActiveDogStatus.ready);
      expect(cubit.state.active, previousAccountDog);

      cubit.reset();
      expect(cubit.state, const ActiveDogState());

      // Login na conta nova: a API passa a devolver os cães dela.
      when(() => dogRepository.getMyDogs())
          .thenAnswer((_) async => [newAccountDog]);
      await cubit.ensureLoaded();

      expect(cubit.state.status, ActiveDogStatus.ready);
      expect(cubit.state.dogs, [newAccountDog]);
      expect(cubit.state.active, newAccountDog);
      // Recarregou de verdade (uma chamada por conta).
      verify(() => dogRepository.getMyDogs()).called(2);
    });

    test('reset no meio de uma carga descarta a resposta da conta anterior',
        () async {
      final previousAccountResponse = Completer<List<DogModel>>();
      when(() => dogRepository.getMyDogs())
          .thenAnswer((_) => previousAccountResponse.future);

      final loading = cubit.refresh();
      cubit.reset();

      // A resposta da conta anterior chega DEPOIS do logout…
      previousAccountResponse.complete([previousAccountDog]);
      await loading;

      // …e é descartada: o estado segue zerado.
      expect(cubit.state, const ActiveDogState());

      // A conta nova carrega do zero, sem herdar seleção.
      when(() => dogRepository.getMyDogs())
          .thenAnswer((_) async => [newAccountDog]);
      await cubit.ensureLoaded();
      expect(cubit.state.dogs, [newAccountDog]);
      expect(cubit.state.active, newAccountDog);
    });
  });
}
