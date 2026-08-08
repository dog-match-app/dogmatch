// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dog_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DogModel _$DogModelFromJson(Map<String, dynamic> json) => DogModel(
  id: json['id'] as String,
  ownerId: json['ownerId'] as String,
  name: json['name'] as String,
  breed: json['breed'] as String,
  sex: $enumDecode(_$DogSexEnumMap, json['sex']),
  birthDate: DateTime.parse(json['birthDate'] as String),
  size: $enumDecode(_$DogSizeEnumMap, json['size']),
  intent: $enumDecode(_$DogIntentEnumMap, json['intent']),
  bio: json['bio'] as String?,
  neutered: json['neutered'] as bool? ?? false,
  pedigree: json['pedigree'] as bool? ?? false,
  active: json['active'] as bool? ?? true,
  photos:
      (json['photos'] as List<dynamic>?)
          ?.map((e) => DogPhotoModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  createdAt: DateTime.parse(json['createdAt'] as String),
  owner: json['owner'] == null
      ? null
      : DogOwnerModel.fromJson(json['owner'] as Map<String, dynamic>),
);

Map<String, dynamic> _$DogModelToJson(DogModel instance) => <String, dynamic>{
  'id': instance.id,
  'ownerId': instance.ownerId,
  'name': instance.name,
  'breed': instance.breed,
  'sex': _$DogSexEnumMap[instance.sex]!,
  'birthDate': instance.birthDate.toIso8601String(),
  'size': _$DogSizeEnumMap[instance.size]!,
  'intent': _$DogIntentEnumMap[instance.intent]!,
  'bio': ?instance.bio,
  'neutered': instance.neutered,
  'pedigree': instance.pedigree,
  'active': instance.active,
  'photos': instance.photos.map((e) => e.toJson()).toList(),
  'createdAt': instance.createdAt.toIso8601String(),
  'owner': ?instance.owner?.toJson(),
};

const _$DogSexEnumMap = {DogSex.male: 'MALE', DogSex.female: 'FEMALE'};

const _$DogSizeEnumMap = {
  DogSize.small: 'SMALL',
  DogSize.medium: 'MEDIUM',
  DogSize.large: 'LARGE',
  DogSize.giant: 'GIANT',
};

const _$DogIntentEnumMap = {
  DogIntent.breeding: 'BREEDING',
  DogIntent.friendship: 'FRIENDSHIP',
  DogIntent.both: 'BOTH',
};
