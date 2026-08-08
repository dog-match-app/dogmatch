import 'package:dio/dio.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/discovery/data/models/discovery_card_model.dart';
import 'package:dogmatch/features/discovery/data/models/swipe_result_model.dart';
import 'package:dogmatch/features/discovery/domain/entities/swipe_action.dart';
import 'package:dogmatch/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: DiscoveryRepository)
class DiscoveryRepositoryImpl implements DiscoveryRepository {
  DiscoveryRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<DiscoveryCardModel>> getFeed({
    required String dogId,
    int radiusKm = 50,
    int limit = 20,
  }) {
    return guardApi(() async {
      final response = await _dio.get<List<dynamic>>(
        '/discovery',
        queryParameters: {
          'dogId': dogId,
          'radiusKm': radiusKm,
          'limit': limit,
        },
      );
      return (response.data ?? [])
          .map(
            (json) => DiscoveryCardModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    });
  }

  @override
  Future<SwipeResultModel> swipe({
    required String swiperDogId,
    required String targetDogId,
    required SwipeAction action,
  }) {
    return guardApi(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/swipes',
        data: {
          'swiperDogId': swiperDogId,
          'targetDogId': targetDogId,
          'action': action.apiValue,
        },
      );
      return SwipeResultModel.fromJson(response.data!);
    });
  }
}
