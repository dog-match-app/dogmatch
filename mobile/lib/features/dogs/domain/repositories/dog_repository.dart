import 'dart:typed_data';

import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_social_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';

/// Contrato de CRUD dos meus cães + fotos.
abstract class DogRepository {
  /// `GET /dogs/mine`.
  Future<List<DogModel>> getMyDogs();

  /// `GET /dogs/:id`.
  Future<DogModel> getDog(String id);

  /// `POST /dogs` (birthDate em ISO-8601 UTC).
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
  });

  /// `PATCH /dogs/:id` — envia apenas os campos não nulos.
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
  });

  /// `DELETE /dogs/:id`.
  Future<void> deleteDog(String id);

  /// Upload presigned (`folder: dogs`) + `POST /dogs/:id/photos { key }`.
  /// Devolve o cão atualizado.
  Future<DogModel> addPhoto(
    String dogId, {
    required Uint8List bytes,
    required String contentType,
  });

  /// `DELETE /dogs/:id/photos/:photoId`. Devolve o cão atualizado.
  Future<DogModel> deletePhoto(String dogId, String photoId);
}
