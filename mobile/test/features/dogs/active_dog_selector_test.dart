import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:dogmatch/features/dogs/presentation/widgets/active_dog_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDogRepository extends Mock implements DogRepository {}

DogModel _makeDog(String id, {required String name}) => DogModel(
      id: id,
      ownerId: 'owner-1',
      name: name,
      breed: 'Vira-lata',
      sex: DogSex.male,
      birthDate: DateTime.utc(2024),
      size: DogSize.medium,
      intent: DogIntent.friendship,
      createdAt: DateTime.utc(2026),
    );

void main() {
  final thor = _makeDog('dog-1', name: 'Thor');
  final luna = _makeDog('dog-2', name: 'Luna');

  late MockDogRepository dogRepository;
  late ActiveDogCubit activeDogCubit;

  setUp(() {
    dogRepository = MockDogRepository();
    activeDogCubit = ActiveDogCubit(dogRepository);
    getIt.registerSingleton<ActiveDogCubit>(activeDogCubit);
  });

  tearDown(() async {
    await activeDogCubit.close();
    await getIt.reset();
  });

  void stubDogs(List<DogModel> dogs) {
    when(() => dogRepository.getMyDogs()).thenAnswer((_) async => dogs);
  }

  Future<void> pumpSelector(WidgetTester tester, Widget selector) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: selector))),
    );
    await tester.pumpAndSettle();
  }

  group('ActiveDogSelector', () {
    testWidgets('com dois cães mostra o ativo e troca a seleção global',
        (tester) async {
      stubDogs([thor, luna]);
      await pumpSelector(tester, const ActiveDogSelector.compact());

      expect(find.text('Thor'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

      await tester.tap(find.text('Thor'));
      await tester.pumpAndSettle();
      expect(find.text('Escolher cão'), findsOneWidget);

      await tester.tap(find.text('Luna'));
      await tester.pumpAndSettle();

      expect(activeDogCubit.state.active?.id, luna.id);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Thor'), findsNothing);
    });

    testWidgets('com um cão só mostra o nome, sem afordância de troca',
        (tester) async {
      stubDogs([thor]);
      await pumpSelector(tester, const ActiveDogSelector.row(label: 'Curtir como'));

      expect(find.text('Thor'), findsOneWidget);
      expect(find.text('Trocar'), findsNothing);

      await tester.tap(find.text('Thor'));
      await tester.pumpAndSettle();
      expect(find.text('Escolher cão'), findsNothing);
    });

    testWidgets('readOnly mostra o cão informado e não responde a toque',
        (tester) async {
      stubDogs([thor, luna]);
      await activeDogCubit.ensureLoaded();
      await pumpSelector(
        tester,
        ActiveDogSelector.readOnly(dog: luna, label: 'Conversando como'),
      );

      expect(find.text('CONVERSANDO COMO'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Trocar'), findsNothing);

      await tester.tap(find.text('Luna'));
      await tester.pumpAndSettle();

      expect(find.text('Escolher cão'), findsNothing);
      expect(activeDogCubit.state.active?.id, thor.id);
    });

    testWidgets('sem cães mostra o CTA de cadastro', (tester) async {
      stubDogs([]);
      await pumpSelector(tester, const ActiveDogSelector.compact());

      expect(find.text('Cadastre um cão'), findsOneWidget);
    });
  });
}
