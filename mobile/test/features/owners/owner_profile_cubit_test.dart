import 'package:bloc_test/bloc_test.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/owners/data/models/owner_profile_model.dart';
import 'package:dogmatch/features/owners/domain/repositories/owners_repository.dart';
import 'package:dogmatch/features/owners/presentation/cubit/owner_profile_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOwnersRepository extends Mock implements OwnersRepository {}

void main() {
  final dog = DogModel(
    id: 'dog-1',
    ownerId: 'owner-1',
    name: 'Luna',
    breed: 'Border Collie',
    sex: DogSex.female,
    birthDate: DateTime.utc(2024, 2),
    size: DogSize.medium,
    intent: DogIntent.both,
    createdAt: DateTime.utc(2026),
  );

  final profile = OwnerProfileModel(
    id: 'owner-1',
    name: 'Ana Silva',
    city: 'São Paulo',
    memberSince: DateTime.utc(2026, 8),
    distanceKm: 4.6,
    stats: const OwnerStatsModel(dogs: 1, matches: 3),
    dogs: [dog],
  );

  late MockOwnersRepository ownersRepository;

  setUp(() {
    ownersRepository = MockOwnersRepository();
  });

  OwnerProfileCubit buildCubit() => OwnerProfileCubit(ownersRepository);

  group('OwnerProfileCubit', () {
    blocTest<OwnerProfileCubit, OwnerProfileState>(
      'emite [loading, success] com o perfil quando o fetch dá certo',
      build: () {
        when(() => ownersRepository.getOwnerProfile('owner-1'))
            .thenAnswer((_) async => profile);
        return buildCubit();
      },
      act: (cubit) => cubit.load('owner-1'),
      expect: () => [
        const OwnerProfileState(status: OwnerProfileStatus.loading),
        OwnerProfileState(
          status: OwnerProfileStatus.success,
          profile: profile,
        ),
      ],
      verify: (_) {
        verify(() => ownersRepository.getOwnerProfile('owner-1')).called(1);
      },
    );

    blocTest<OwnerProfileCubit, OwnerProfileState>(
      'emite [loading, error] com a mensagem da ApiException quando falha',
      build: () {
        when(() => ownersRepository.getOwnerProfile('owner-1')).thenThrow(
          const ApiException(
            'Não encontramos o que você procura.',
            statusCode: 404,
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.load('owner-1'),
      expect: () => const [
        OwnerProfileState(status: OwnerProfileStatus.loading),
        OwnerProfileState(
          status: OwnerProfileStatus.error,
          message: 'Não encontramos o que você procura.',
        ),
      ],
    );
  });
}
