import 'package:dogmatch/app/di/injection.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_social_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:dogmatch/features/dogs/presentation/cubit/my_dogs_cubit.dart';
import 'package:dogmatch/features/dogs/presentation/pages/dog_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDogRepository extends Mock implements DogRepository {}

void main() {
  late MockDogRepository dogRepository;
  late ActiveDogCubit activeDogCubit;

  setUpAll(() {
    registerFallbackValue(DogSex.male);
    registerFallbackValue(DogSize.medium);
    registerFallbackValue(DogIntent.both);
    registerFallbackValue(DateTime(2020));
    registerFallbackValue(const DogSocialModel());
  });

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

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DogFormPage()));
    await tester.pumpAndSettle();
  }

  Finder fieldByLabel(String label) =>
      find.widgetWithText(TextFormField, label);

  group('DogFormPage — validação', () {
    testWidgets(
        'salvar com erros rola até o primeiro campo inválido e, corrigida a '
        'data, o erro some sem novo salvar', (tester) async {
      await pumpForm(tester);

      // Nome vazio + raça vazia + data inexistente no calendário.
      await tester.enterText(fieldByLabel('Data de nascimento'), '31/02/2024');
      await tester.pump();

      // O botão fica no fim do formulário — a tela está rolada para baixo,
      // com o campo Nome fora da viewport, quando o usuário tenta salvar.
      await tester.ensureVisible(find.text('Cadastrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();

      // Erros visíveis…
      expect(find.text('Informe o nome do cão.'), findsOneWidget);
      expect(find.text('Data inválida'), findsOneWidget);

      // …e o formulário rolou até o PRIMEIRO campo com erro (Nome), que
      // voltou para dentro da viewport.
      final viewportHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final nameRect = tester.getRect(fieldByLabel('Nome'));
      expect(nameRect.top, greaterThanOrEqualTo(0));
      expect(nameRect.bottom, lessThanOrEqualTo(viewportHeight));

      // Corrigir a data limpa o erro DELA enquanto digita — sem apertar
      // Cadastrar de novo (autovalidação após a primeira tentativa).
      await tester.ensureVisible(fieldByLabel('Data de nascimento'));
      await tester.pumpAndSettle();
      await tester.enterText(fieldByLabel('Data de nascimento'), '15/03/2022');
      await tester.pump();

      expect(find.text('Data inválida'), findsNothing);
      // O erro do nome (ainda vazio) permanece.
      expect(find.text('Informe o nome do cão.'), findsOneWidget);

      // Nada foi salvo em momento algum.
      verifyNever(
        () => dogRepository.createDog(
          name: any(named: 'name'),
          breed: any(named: 'breed'),
          sex: any(named: 'sex'),
          birthDate: any(named: 'birthDate'),
          size: any(named: 'size'),
          intent: any(named: 'intent'),
          bio: any(named: 'bio'),
          neutered: any(named: 'neutered'),
          pedigree: any(named: 'pedigree'),
          social: any(named: 'social'),
        ),
      );
    });
  });
}
