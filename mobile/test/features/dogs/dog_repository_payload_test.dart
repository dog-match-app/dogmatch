import 'package:dio/dio.dart';
import 'package:dogmatch/core/network/file_uploader.dart';
import 'package:dogmatch/features/dogs/data/models/dog_social_model.dart';
import 'package:dogmatch/features/dogs/data/repositories/dog_repository_impl.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _MockFileUploader extends Mock implements FileUploader {}

/// Resposta mínima aceita por `DogModel.fromJson`.
Map<String, dynamic> _dogJson() => {
      'id': 'dog-1',
      'ownerId': 'owner-1',
      'name': 'Rex',
      'breed': 'SRD',
      'sex': 'MALE',
      'birthDate': '2022-01-15T00:00:00.000Z',
      'size': 'MEDIUM',
      'intent': 'BOTH',
      'neutered': false,
      'pedigree': false,
      'active': true,
      'photos': <dynamic>[],
      'createdAt': '2026-08-01T00:00:00.000Z',
    };

void main() {
  late _MockDio dio;
  late DogRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    dio = _MockDio();
    repository = DogRepositoryImpl(dio, _MockFileUploader());
  });

  Response<Map<String, dynamic>> response(String path) => Response(
        data: _dogJson(),
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );

  const social = DogSocialModel(
    whatsapp: '+55 11 91234-0002',
    instagram: '@rex.bulldog',
  );

  test('createDog envia redes sociais como campos soltos', () async {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((_) async => response('/dogs'));

    await repository.createDog(
      name: 'Rex',
      breed: 'SRD',
      sex: DogSex.male,
      birthDate: DateTime.utc(2022, 1, 15),
      size: DogSize.medium,
      intent: DogIntent.both,
      social: social,
    );

    final data = verify(
      () => dio.post<Map<String, dynamic>>(
        any(),
        data: captureAny(named: 'data'),
      ),
    ).captured.single as Map<String, dynamic>;

    // A API usa forbidNonWhitelisted: um objeto `social` aninhado dá 400.
    expect(data.containsKey('social'), isFalse);
    expect(data['whatsapp'], '+55 11 91234-0002');
    expect(data['instagram'], '@rex.bulldog');
    expect(data['pinterest'], isNull);
    expect(data['telegram'], isNull);
  });

  test('updateDog envia redes sociais como campos soltos', () async {
    when(() => dio.patch<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((_) async => response('/dogs/dog-1'));

    await repository.updateDog('dog-1', name: 'Rex', social: social);

    final data = verify(
      () => dio.patch<Map<String, dynamic>>(
        any(),
        data: captureAny(named: 'data'),
      ),
    ).captured.single as Map<String, dynamic>;

    expect(data.containsKey('social'), isFalse);
    expect(data['whatsapp'], '+55 11 91234-0002');
    expect(data['name'], 'Rex');
  });
}
