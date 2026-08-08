import 'package:dio/dio.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/matches/data/models/match_model.dart';
import 'package:dogmatch/features/matches/domain/repositories/match_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: MatchRepository)
class MatchRepositoryImpl implements MatchRepository {
  MatchRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<MatchModel>> getMatches({String? dogId}) {
    return guardApi(() async {
      final response = await _dio.get<List<dynamic>>(
        '/matches',
        queryParameters: {'dogId': ?dogId},
      );
      return (response.data ?? [])
          .map((json) => MatchModel.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<MatchModel?> findMatch(String matchId) async {
    final matches = await getMatches();
    for (final match in matches) {
      if (match.id == matchId) return match;
    }
    return null;
  }
}
