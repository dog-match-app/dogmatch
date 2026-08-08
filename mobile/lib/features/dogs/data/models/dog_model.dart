import 'package:dogmatch/features/dogs/data/models/dog_owner_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_photo_model.dart';
import 'package:dogmatch/features/dogs/data/models/dog_social_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'dog_model.g.dart';

/// `DogDto` do contrato da API.
@JsonSerializable()
class DogModel extends Equatable {
  const DogModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.breed,
    required this.sex,
    required this.birthDate,
    required this.size,
    required this.intent,
    this.bio,
    this.neutered = false,
    this.pedigree = false,
    this.active = true,
    this.photos = const [],
    this.social,
    required this.createdAt,
    this.owner,
  });

  factory DogModel.fromJson(Map<String, dynamic> json) =>
      _$DogModelFromJson(json);

  final String id;
  final String ownerId;
  final String name;
  final String breed;
  final DogSex sex;
  final DateTime birthDate;
  final DogSize size;
  final DogIntent intent;
  final String? bio;
  final bool neutered;
  final bool pedigree;
  final bool active;
  final List<DogPhotoModel> photos;

  /// Redes sociais do cão (`DogDto.social`, §3.5.3); pode vir ausente.
  final DogSocialModel? social;

  final DateTime createdAt;

  /// Presente apenas em `GET /dogs/:id` (o endpoint inclui `owner`).
  final DogOwnerModel? owner;

  Map<String, dynamic> toJson() => _$DogModelToJson(this);

  /// Fotos ordenadas por `position`.
  List<DogPhotoModel> get sortedPhotos {
    final sorted = [...photos]
      ..sort((a, b) => a.position.compareTo(b.position));
    return sorted;
  }

  /// URL da foto principal (menor `position`), se houver.
  String? get mainPhotoUrl =>
      photos.isEmpty ? null : sortedPhotos.first.url;

  /// Idade em meses completos calculada de [birthDate] (mínimo 0).
  int get ageInMonths {
    final now = DateTime.now();
    var months =
        (now.year - birthDate.year) * 12 + (now.month - birthDate.month);
    if (now.day < birthDate.day) months--;
    if (months < 0) months = 0;
    return months;
  }

  /// Idade curta: `"2a"` (anos) ou `"8m"` (meses).
  String get ageLabel {
    final months = ageInMonths;
    if (months >= 12) return '${months ~/ 12}a';
    return '${months}m';
  }

  /// Idade por extenso: `"8 meses"`, `"1 ano"`, `"5 anos"`.
  String get ageLongLabel {
    final months = ageInMonths;
    if (months >= 12) {
      final years = months ~/ 12;
      return years == 1 ? '1 ano' : '$years anos';
    }
    return months == 1 ? '1 mês' : '$months meses';
  }

  @override
  List<Object?> get props => [
        id,
        ownerId,
        name,
        breed,
        sex,
        birthDate,
        size,
        intent,
        bio,
        neutered,
        pedigree,
        active,
        photos,
        social,
        createdAt,
        owner,
      ];
}
