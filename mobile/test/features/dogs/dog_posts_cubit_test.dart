import 'package:bloc_test/bloc_test.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/dogs/data/models/dog_post_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_type.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_posts_repository.dart';
import 'package:dogmatch/features/dogs/presentation/cubit/dog_posts_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDogPostsRepository extends Mock implements DogPostsRepository {}

DogPostModel buildPost(String id, {DateTime? createdAt}) {
  final date = createdAt ?? DateTime.utc(2026, 8, 1);
  return DogPostModel(
    id: id,
    dogId: 'dog-1',
    type: DogPostType.text,
    text: 'Primeiro passeio da Luna 🐾',
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  final older = buildPost('post-older', createdAt: DateTime.utc(2026, 8, 1));
  final newer = buildPost('post-newer', createdAt: DateTime.utc(2026, 8, 5));

  late MockDogPostsRepository repository;

  setUp(() {
    repository = MockDogPostsRepository();
  });

  DogPostsCubit buildCubit() => DogPostsCubit(repository);

  group('DogPostsCubit.load', () {
    blocTest<DogPostsCubit, DogPostsState>(
      'emite [loading, success] com os posts em createdAt desc',
      build: () {
        when(() => repository.getPosts('dog-1'))
            .thenAnswer((_) async => [older, newer]);
        return buildCubit();
      },
      act: (cubit) => cubit.load('dog-1'),
      expect: () => [
        const DogPostsState(status: DogPostsStatus.loading),
        DogPostsState(status: DogPostsStatus.success, posts: [newer, older]),
      ],
      verify: (_) {
        verify(() => repository.getPosts('dog-1')).called(1);
      },
    );

    blocTest<DogPostsCubit, DogPostsState>(
      'emite [loading, error] com a mensagem da ApiException quando falha',
      build: () {
        when(() => repository.getPosts('dog-1')).thenThrow(
          const ApiException('Erro no servidor. Tente novamente mais tarde.'),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.load('dog-1'),
      expect: () => const [
        DogPostsState(status: DogPostsStatus.loading),
        DogPostsState(
          status: DogPostsStatus.error,
          message: 'Erro no servidor. Tente novamente mais tarde.',
        ),
      ],
    );
  });

  group('DogPostsCubit.delete (otimista)', () {
    blocTest<DogPostsCubit, DogPostsState>(
      'remove o post da lista imediatamente e mantém após o sucesso',
      build: () {
        when(() => repository.getPosts('dog-1'))
            .thenAnswer((_) async => [newer, older]);
        when(() => repository.deletePost('dog-1', 'post-older'))
            .thenAnswer((_) async {});
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load('dog-1');
        await cubit.delete('post-older');
      },
      expect: () => [
        const DogPostsState(status: DogPostsStatus.loading),
        DogPostsState(status: DogPostsStatus.success, posts: [newer, older]),
        DogPostsState(status: DogPostsStatus.success, posts: [newer]),
      ],
      verify: (_) {
        verify(() => repository.deletePost('dog-1', 'post-older')).called(1);
      },
    );

    blocTest<DogPostsCubit, DogPostsState>(
      'restaura a lista anterior com actionError quando o DELETE falha',
      build: () {
        when(() => repository.getPosts('dog-1'))
            .thenAnswer((_) async => [newer, older]);
        when(() => repository.deletePost('dog-1', 'post-older')).thenThrow(
          const ApiException('Erro no servidor. Tente novamente mais tarde.'),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load('dog-1');
        await cubit.delete('post-older');
      },
      expect: () => [
        const DogPostsState(status: DogPostsStatus.loading),
        DogPostsState(status: DogPostsStatus.success, posts: [newer, older]),
        DogPostsState(status: DogPostsStatus.success, posts: [newer]),
        DogPostsState(
          status: DogPostsStatus.success,
          posts: [newer, older],
          actionError: 'Erro no servidor. Tente novamente mais tarde.',
        ),
      ],
    );
  });

  group('DogPostsState.canAddMore', () {
    test('true abaixo do limite de 10 posts', () {
      final state = DogPostsState(
        status: DogPostsStatus.success,
        posts: [for (var i = 0; i < 9; i++) buildPost('post-$i')],
      );
      expect(state.count, 9);
      expect(state.canAddMore, isTrue);
    });

    test('false com 10 posts (limite atingido)', () {
      final state = DogPostsState(
        status: DogPostsStatus.success,
        posts: [for (var i = 0; i < 10; i++) buildPost('post-$i')],
      );
      expect(state.count, 10);
      expect(state.canAddMore, isFalse);
    });
  });

  group('dogPostErrorMessage', () {
    test('POST_LIMIT_REACHED (backendCode) vira a mensagem amigável', () {
      const exception = ApiException(
        'Dados inválidos. Verifique os campos e tente novamente.',
        statusCode: 400,
        backendCode: 'POST_LIMIT_REACHED',
      );
      expect(dogPostErrorMessage(exception), 'Limite de 10 posts atingido');
    });

    test('mensagem crua contendo POST_LIMIT_REACHED também é convertida', () {
      const exception =
          ApiException('POST_LIMIT_REACHED', statusCode: 400);
      expect(dogPostErrorMessage(exception), 'Limite de 10 posts atingido');
    });

    test('outros erros mantêm a mensagem da ApiException', () {
      const exception = ApiException('Não encontramos o que você procura.');
      expect(
        dogPostErrorMessage(exception),
        'Não encontramos o que você procura.',
      );
    });
  });
}
