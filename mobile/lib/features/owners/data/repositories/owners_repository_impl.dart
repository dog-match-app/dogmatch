import 'package:dio/dio.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/owners/data/models/owner_profile_model.dart';
import 'package:dogmatch/features/owners/domain/repositories/owners_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: OwnersRepository)
class OwnersRepositoryImpl implements OwnersRepository {
  OwnersRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<OwnerProfileModel> getOwnerProfile(String userId) {
    return guardApi(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/users/$userId/profile');
      return OwnerProfileModel.fromJson(response.data!);
    });
  }
}
