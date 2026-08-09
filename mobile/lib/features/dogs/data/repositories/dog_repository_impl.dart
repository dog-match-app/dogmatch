import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/network/file_uploader.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_social_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: DogRepository)
class DogRepositoryImpl implements DogRepository {
  DogRepositoryImpl(this._dio, this._fileUploader);

  final Dio _dio;
  final FileUploader _fileUploader;

  @override
  Future<List<DogModel>> getMyDogs() {
    return guardApi(() async {
      final response = await _dio.get<List<dynamic>>('/dogs/mine');
      return (response.data ?? [])
          .map((json) => DogModel.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<DogModel> getDog(String id) {
    return guardApi(() async {
      final response = await _dio.get<Map<String, dynamic>>('/dogs/$id');
      return DogModel.fromJson(response.data!);
    });
  }

  @override
  Future<DogModel> createDog({
    required String name,
    required String breed,
    required DogSex sex,
    required DateTime birthDate,
    required DogSize size,
    required DogIntent intent,
    String? bio,
    bool neutered = false,
    bool pedigree = false,
    DogSocialModel? social,
  }) {
    return guardApi(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/dogs',
        data: {
          'name': name,
          'breed': breed,
          'sex': sex.apiValue,
          'birthDate': birthDate.toUtc().toIso8601String(),
          'size': size.apiValue,
          'intent': intent.apiValue,
          if (bio != null && bio.isNotEmpty) 'bio': bio,
          'neutered': neutered,
          'pedigree': pedigree,
          // Redes sociais vão como campos soltos (ARCHITECTURE §4); o DTO da API
          // rejeita chaves desconhecidas, então nada de objeto aninhado aqui.
          ...?social?.toRequestFields(),
        },
      );
      return DogModel.fromJson(response.data!);
    });
  }

  @override
  Future<DogModel> updateDog(
    String id, {
    String? name,
    String? breed,
    DogSex? sex,
    DateTime? birthDate,
    DogSize? size,
    DogIntent? intent,
    String? bio,
    bool? neutered,
    bool? pedigree,
    DogSocialModel? social,
  }) {
    return guardApi(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/dogs/$id',
        data: {
          'name': ?name,
          'breed': ?breed,
          'sex': ?sex?.apiValue,
          'birthDate': ?birthDate?.toUtc().toIso8601String(),
          'size': ?size?.apiValue,
          'intent': ?intent?.apiValue,
          'bio': ?bio,
          'neutered': ?neutered,
          'pedigree': ?pedigree,
          // Campos soltos (ARCHITECTURE §4); string vazia limpa a rede no backend.
          ...?social?.toRequestFields(),
        },
      );
      return DogModel.fromJson(response.data!);
    });
  }

  @override
  Future<void> deleteDog(String id) {
    return guardApi(() async {
      await _dio.delete<void>('/dogs/$id');
    });
  }

  @override
  Future<DogModel> addPhoto(
    String dogId, {
    required Uint8List bytes,
    required String contentType,
  }) async {
    final upload = await _fileUploader.uploadBytes(
      bytes: bytes,
      contentType: contentType,
      folder: 'dogs',
    );
    return guardApi(() async {
      await _dio.post<Map<String, dynamic>>(
        '/dogs/$dogId/photos',
        data: {'key': upload.key},
      );
      return getDog(dogId);
    });
  }

  @override
  Future<DogModel> deletePhoto(String dogId, String photoId) {
    return guardApi(() async {
      await _dio.delete<void>('/dogs/$dogId/photos/$photoId');
      return getDog(dogId);
    });
  }
}
