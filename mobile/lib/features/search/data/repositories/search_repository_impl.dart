import 'package:dio/dio.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/search/data/models/search_result_model.dart';
import 'package:dogmatch/features/search/domain/entities/search_filters.dart';
import 'package:dogmatch/features/search/domain/repositories/search_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: SearchRepository)
class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<SearchResultModel> search(
    SearchFilters filters, {
    String? dogId,
    bool excludeSwiped = false,
    int page = 1,
    int limit = 20,
  }) {
    return guardApi(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/discovery/search',
        queryParameters: filters.toQueryParams(
          dogId: dogId,
          excludeSwiped: excludeSwiped,
          page: page,
          limit: limit,
        ),
      );
      return SearchResultModel.fromJson(response.data!);
    });
  }
}
