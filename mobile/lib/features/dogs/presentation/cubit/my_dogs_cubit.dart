import 'dart:typed_data';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/dogs/data/models/dog_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_enums.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'my_dogs_state.dart';

/// Lista/criação/edição/remoção dos meus cães + fotos.
@injectable
class MyDogsCubit extends Cubit<MyDogsState> {
  MyDogsCubit(this._dogRepository) : super(const MyDogsState());

  final DogRepository _dogRepository;

  Future<void> load() async {
    emit(state.copyWith(status: MyDogsStatus.loading));
    try {
      final dogs = await _dogRepository.getMyDogs();
      emit(state.copyWith(status: MyDogsStatus.loaded, dogs: dogs));
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          status: MyDogsStatus.error,
          errorMessage: exception.message,
        ),
      );
    }
  }

  /// Prepara o formulário de edição: usa [initial] se veio via `extra`,
  /// senão busca `GET /dogs/:id`.
  Future<void> loadForEdit(String dogId, {DogModel? initial}) async {
    if (initial != null) {
      emit(state.copyWith(status: MyDogsStatus.loaded, editingDog: initial));
      return;
    }
    emit(state.copyWith(status: MyDogsStatus.loading));
    try {
      final dog = await _dogRepository.getDog(dogId);
      emit(state.copyWith(status: MyDogsStatus.loaded, editingDog: dog));
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          status: MyDogsStatus.error,
          errorMessage: exception.message,
        ),
      );
    }
  }

  Future<void> create({
    required String name,
    required String breed,
    required DogSex sex,
    required DateTime birthDate,
    required DogSize size,
    required DogIntent intent,
    String? bio,
    required bool neutered,
    required bool pedigree,
  }) async {
    emit(state.copyWith(saving: true));
    try {
      final dog = await _dogRepository.createDog(
        name: name,
        breed: breed,
        sex: sex,
        birthDate: birthDate,
        size: size,
        intent: intent,
        bio: bio,
        neutered: neutered,
        pedigree: pedigree,
      );
      emit(
        state.copyWith(
          status: MyDogsStatus.loaded,
          saving: false,
          editingDog: dog,
          savedDog: dog,
          successMessage: 'Cão cadastrado! Agora adicione fotos.',
        ),
      );
    } on ApiException catch (exception) {
      emit(state.copyWith(saving: false, errorMessage: exception.message));
    }
  }

  Future<void> update(
    String id, {
    required String name,
    required String breed,
    required DogSex sex,
    required DateTime birthDate,
    required DogSize size,
    required DogIntent intent,
    String? bio,
    required bool neutered,
    required bool pedigree,
  }) async {
    emit(state.copyWith(saving: true));
    try {
      final dog = await _dogRepository.updateDog(
        id,
        name: name,
        breed: breed,
        sex: sex,
        birthDate: birthDate,
        size: size,
        intent: intent,
        bio: bio,
        neutered: neutered,
        pedigree: pedigree,
      );
      emit(
        state.copyWith(
          saving: false,
          editingDog: dog,
          savedDog: dog,
          successMessage: 'Alterações salvas!',
        ),
      );
    } on ApiException catch (exception) {
      emit(state.copyWith(saving: false, errorMessage: exception.message));
    }
  }

  Future<void> delete(String id) async {
    emit(state.copyWith(saving: true));
    try {
      await _dogRepository.deleteDog(id);
      emit(state.copyWith(saving: false, deleted: true));
    } on ApiException catch (exception) {
      emit(state.copyWith(saving: false, errorMessage: exception.message));
    }
  }

  Future<void> addPhoto({
    required String dogId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    emit(state.copyWith(photoBusy: true));
    try {
      final dog = await _dogRepository.addPhoto(
        dogId,
        bytes: bytes,
        contentType: contentType,
      );
      emit(state.copyWith(photoBusy: false, editingDog: dog));
    } on ApiException catch (exception) {
      emit(state.copyWith(photoBusy: false, errorMessage: exception.message));
    }
  }

  Future<void> deletePhoto({
    required String dogId,
    required String photoId,
  }) async {
    emit(state.copyWith(photoBusy: true));
    try {
      final dog = await _dogRepository.deletePhoto(dogId, photoId);
      emit(state.copyWith(photoBusy: false, editingDog: dog));
    } on ApiException catch (exception) {
      emit(state.copyWith(photoBusy: false, errorMessage: exception.message));
    }
  }
}
