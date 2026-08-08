import 'package:dogmatch/features/discovery/data/models/discovery_card_model.dart';
import 'package:dogmatch/features/discovery/data/models/swipe_result_model.dart';
import 'package:dogmatch/features/discovery/domain/entities/swipe_action.dart';

/// Contrato do feed de descoberta e swipes.
abstract class DiscoveryRepository {
  /// `GET /discovery?dogId=&radiusKm=&limit=`.
  Future<List<DiscoveryCardModel>> getFeed({
    required String dogId,
    int radiusKm = 50,
    int limit = 20,
  });

  /// `POST /swipes`.
  Future<SwipeResultModel> swipe({
    required String swiperDogId,
    required String targetDogId,
    required SwipeAction action,
  });
}
