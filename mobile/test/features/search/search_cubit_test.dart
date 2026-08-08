import 'package:bloc_test/bloc_test.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/discovery/presentation/cubit/active_dog_cubit.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_owner_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:dogmatch/features/search/data/models/search_card_model.dart';
import 'package:dogmatch/features/search/data/models/search_result_model.dart';
import 'package:dogmatch/features/search/domain/entities/search_filters.dart';
import 'package:dogmatch/features/search/domain/repositories/search_repository.dart';
import 'package:dogmatch/features/search/presentation/cubit/search_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSearchRepository extends Mock implements SearchRepository {}

class MockDogRepository extends Mock implements DogRepository {}

class MockActiveDogCubit extends MockCubit<DogModel?>
    implements ActiveDogCubit {}

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

SearchCardModel _makeCard(String id, {String name = 'Rex'}) => SearchCardModel(
      dog: _makeDog(id, name: name),
      distanceKm: 2.3,
      owner: DogOwnerModel(id: 'owner-$id', name: 'Tutor', city: 'São Paulo'),
    );

void main() {
  final myDog = _makeDog('my-dog', name: 'Bidu');
  final card1 = _makeCard('dog-1', name: 'Luna');
  final card2 = _makeCard('dog-2', name: 'Thor');

  late MockSearchRepository searchRepository;
  late MockDogRepository dogRepository;
  late MockActiveDogCubit activeDogCubit;

  setUpAll(() {
    registerFallbackValue(const SearchFilters());
  });

  setUp(() {
    searchRepository = MockSearchRepository();
    dogRepository = MockDogRepository();
    activeDogCubit = MockActiveDogCubit();
    when(() => activeDogCubit.state).thenReturn(myDog);
  });

  SearchCubit buildCubit() =>
      SearchCubit(searchRepository, dogRepository, activeDogCubit);

  void stubSearch(SearchResultModel result) {
    when(
      () => searchRepository.search(
        any(),
        dogId: any(named: 'dogId'),
        excludeSwiped: any(named: 'excludeSwiped'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => result);
  }

  group('SearchCubit', () {
    blocTest<SearchCubit, SearchState>(
      'search emite [loading, success] com os itens quando a busca dá certo',
      build: () {
        stubSearch(
          SearchResultModel(items: [card1], total: 1, page: 1, pageCount: 1),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.search(),
      expect: () => [
        const SearchState(status: SearchStatus.loading),
        SearchState(
          status: SearchStatus.success,
          items: [card1],
          page: 1,
          total: 1,
          hasMore: false,
        ),
      ],
      verify: (_) {
        verify(
          () => searchRepository.search(
            const SearchFilters(),
            dogId: myDog.id,
            excludeSwiped: false,
            page: 1,
            limit: 20,
          ),
        ).called(1);
      },
    );

    blocTest<SearchCubit, SearchState>(
      'loadMore acumula os itens e é ignorado quando hasMore = false',
      build: () {
        stubSearch(
          SearchResultModel(items: [card2], total: 2, page: 2, pageCount: 2),
        );
        return buildCubit();
      },
      seed: () => SearchState(
        status: SearchStatus.success,
        items: [card1],
        page: 1,
        total: 2,
        hasMore: true,
      ),
      act: (cubit) async {
        await cubit.loadMore();
        // hasMore agora é false: a segunda chamada não emite nada.
        await cubit.loadMore();
      },
      expect: () => [
        SearchState(
          status: SearchStatus.loadingMore,
          items: [card1],
          page: 1,
          total: 2,
          hasMore: true,
        ),
        SearchState(
          status: SearchStatus.success,
          items: [card1, card2],
          page: 2,
          total: 2,
          hasMore: false,
        ),
      ],
      verify: (_) {
        verify(
          () => searchRepository.search(
            const SearchFilters(),
            dogId: myDog.id,
            excludeSwiped: false,
            page: 2,
            limit: 20,
          ),
        ).called(1);
      },
    );

    blocTest<SearchCubit, SearchState>(
      'search emite [loading, error] com a mensagem da ApiException '
      'quando a busca falha',
      build: () {
        when(
          () => searchRepository.search(
            any(),
            dogId: any(named: 'dogId'),
            excludeSwiped: any(named: 'excludeSwiped'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(
          const ApiException(
            'Erro no servidor. Tente novamente mais tarde.',
            statusCode: 500,
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.search(),
      expect: () => const [
        SearchState(status: SearchStatus.loading),
        SearchState(
          status: SearchStatus.error,
          message: 'Erro no servidor. Tente novamente mais tarde.',
        ),
      ],
    );
  });
}
