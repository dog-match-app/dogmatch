import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_social_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:dogmatch/features/dogs/presentation/cubit/my_dogs_cubit.dart';
import 'package:dogmatch/features/dogs/presentation/pages/dog_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDogRepository extends Mock implements DogRepository {}

DogModel _makeDog() => DogModel(
      id: 'dog-1',
      ownerId: 'owner-1',
      name: 'Rex',
      breed: 'Golden Retriever',
      sex: DogSex.female,
      birthDate: DateTime.utc(2022, 3, 15),
      size: DogSize.large,
      intent: DogIntent.both,
      bio: 'Muito dócil e brincalhona',
      neutered: true,
      pedigree: true,
      social: const DogSocialModel(
        whatsapp: '+55 11 98888-7777',
        instagram: '@rex.insta',
        pinterest: '@rex.pin',
        telegram: '@rex.tele',
      ),
      createdAt: DateTime.utc(2026),
    );

void main() {
  late MockDogRepository dogRepository;
  late ActiveDogCubit activeDogCubit;

  setUp(() {
    dogRepository = MockDogRepository();
    when(() => dogRepository.getMyDogs()).thenAnswer((_) async => []);
    activeDogCubit = ActiveDogCubit(dogRepository);
    getIt.registerFactory<MyDogsCubit>(
      () => MyDogsCubit(dogRepository, activeDogCubit),
    );
  });

  tearDown(() async {
    await activeDogCubit.close();
    await getIt.reset();
  });

  Future<void> pumpForm(WidgetTester tester, {DogModel? initialDog}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DogFormPage(dogId: 'dog-1', initialDog: initialDog),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('DogFormPage — prefill na edição', () {
    testWidgets('cão vindo via extra preenche todos os campos',
        (tester) async {
      final dog = _makeDog();
      await pumpForm(tester, initialDog: dog);

      expect(find.text('Editar cão'), findsOneWidget);
      expect(find.text('Rex'), findsOneWidget);
      expect(find.text('Golden Retriever'), findsOneWidget);
      expect(find.text('15/03/2022'), findsOneWidget);
      expect(find.text('Muito dócil e brincalhona'), findsOneWidget);
      expect(find.text('+55 11 98888-7777'), findsOneWidget);
      expect(find.text('@rex.insta'), findsOneWidget);
      expect(find.text('@rex.pin'), findsOneWidget);
      expect(find.text('@rex.tele'), findsOneWidget);

      final sexSelector = tester.widget<SegmentedButton<DogSex>>(
        find.byType(SegmentedButton<DogSex>),
      );
      expect(sexSelector.selected, {DogSex.female});

      final sizeField = tester.widget<DropdownButtonFormField<DogSize>>(
        find.byType(DropdownButtonFormField<DogSize>),
      );
      expect(sizeField.initialValue, DogSize.large);

      final intentChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Cruzamento e amizade'),
      );
      expect(intentChip.selected, isTrue);

      final neuteredSwitch = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Castrado'),
      );
      expect(neuteredSwitch.value, isTrue);

      final pedigreeSwitch = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Pedigree'),
      );
      expect(pedigreeSwitch.value, isTrue);
    });

    testWidgets('sem extra, busca GET /dogs/:id e preenche', (tester) async {
      final dog = _makeDog();
      when(() => dogRepository.getDog('dog-1')).thenAnswer((_) async => dog);

      await pumpForm(tester);

      verify(() => dogRepository.getDog('dog-1')).called(1);
      expect(find.text('Rex'), findsOneWidget);
      expect(find.text('Golden Retriever'), findsOneWidget);
      expect(find.text('15/03/2022'), findsOneWidget);
    });
  });
}
