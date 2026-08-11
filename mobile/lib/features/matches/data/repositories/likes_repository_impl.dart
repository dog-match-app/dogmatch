import 'package:dio/dio.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/matches/data/models/like_received_model.dart';
import 'package:dogmatch/features/matches/domain/repositories/likes_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: LikesRepository)
class LikesRepositoryImpl implements LikesRepository {
  LikesRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<LikesReceivedModel> getReceived({String? dogId}) {
    return guardApi(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/swipes/received',
        queryParameters: {'dogId': ?dogId},
      );
      return LikesReceivedModel.fromJson(response.data ?? const {});
    });
  }
}
