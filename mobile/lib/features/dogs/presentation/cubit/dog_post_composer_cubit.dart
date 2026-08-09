import 'dart:typed_data';

import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/core/network/file_uploader.dart';
import 'package:dogmatch/features/dogs/data/models/dog_post_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_draft.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_rules.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_type.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_posts_repository.dart';
import 'package:dogmatch/features/dogs/presentation/cubit/dog_posts_cubit.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'dog_post_composer_state.dart';

/// Estado do draft de um post (criação e edição): tipo, texto, imagens com
/// upload presigned imediato (folder `dogs`) e legendas posicionadas por
/// imagem. `save` cria (`POST`) ou substitui o conteúdo (`PATCH`).
@injectable
class DogPostComposerCubit extends Cubit<DogPostComposerState> {
  DogPostComposerCubit(this._repository, this._fileUploader)
      : super(const DogPostComposerState());

  final DogPostsRepository _repository;
  final FileUploader _fileUploader;

  String? _dogId;
  String? _postId;
  int _nextLocalId = 0;

  /// Criação: `postId == null`. Edição: usa [initialPost] se veio via extra;
  /// sem extra (deep link), busca o post na lista `GET /dogs/:id/posts`.
  Future<void> init({
    required String dogId,
    String? postId,
    DogPostModel? initialPost,
  }) async {
    _dogId = dogId;
    _postId = postId;
    if (postId == null) {
      emit(const DogPostComposerState(status: DogPostComposerStatus.ready));
      return;
    }
    if (initialPost != null) {
      _emitPrefilled(initialPost);
      return;
    }
    emit(const DogPostComposerState());
    try {
      final posts = await _repository.getPosts(dogId);
      final post = posts.where((item) => item.id == postId).firstOrNull;
      if (post == null) {
        emit(
          const DogPostComposerState(
            status: DogPostComposerStatus.error,
            message: 'Não encontramos este post.',
          ),
        );
        return;
      }
      _emitPrefilled(post);
    } on ApiException catch (exception) {
      emit(
        DogPostComposerState(
          status: DogPostComposerStatus.error,
          message: exception.message,
        ),
      );
    }
  }

  void _emitPrefilled(DogPostModel post) {
    emit(
      DogPostComposerState(
        status: DogPostComposerStatus.ready,
        isEditing: true,
        type: post.type,
        text: post.text ?? '',
        images: [
          for (final image in post.sortedImages)
            ComposerImage(
              localId: _nextLocalId++,
              key: dogPostKeyFromUrl(image.url),
              url: image.url,
              captions: [
                for (final caption in image.captions)
                  DogPostDraftCaption(
                    text: caption.text,
                    x: caption.x,
                    y: caption.y,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Troca o tipo (apenas na criação — imutável na edição). Imagens além do
  /// máximo do novo tipo são descartadas.
  void selectType(DogPostType type) {
    if (state.isEditing || type == state.type) return;
    final images = state.images.length > type.maxImages
        ? state.images.sublist(0, type.maxImages)
        : state.images;
    emit(state.copyWith(type: type, images: images));
  }

  void textChanged(String text) {
    if (text == state.text) return;
    emit(state.copyWith(text: text));
  }

  /// Sobe a imagem via presigned (folder `dogs`) já na seleção. Em tipos de
  /// imagem única a nova imagem substitui a atual ("trocar"); no carrossel é
  /// adicionada ao final (respeitando o máximo de 8).
  Future<void> addImage({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final type = state.type;
    if (type == DogPostType.text) return;
    final entry = ComposerImage(
      localId: _nextLocalId++,
      bytes: bytes,
      uploading: true,
    );
    if (type == DogPostType.carousel) {
      if (state.images.length >= maxCarouselImages) {
        emit(
          state.copyWith(
            errorMessage:
                'O carrossel aceita no máximo $maxCarouselImages imagens.',
          ),
        );
        return;
      }
      emit(state.copyWith(images: [...state.images, entry]));
    } else {
      emit(state.copyWith(images: [entry]));
    }
    try {
      final upload = await _fileUploader.uploadBytes(
        bytes: bytes,
        contentType: contentType,
        folder: 'dogs',
      );
      _patchImage(
        entry.localId,
        (image) => image.copyWith(
          key: upload.key,
          url: upload.publicUrl,
          uploading: false,
        ),
      );
    } on ApiException catch (exception) {
      // Falhou: tira a imagem da lista e avisa a UI.
      emit(
        state.copyWith(
          images: state.images
              .where((image) => image.localId != entry.localId)
              .toList(),
          errorMessage: exception.message,
        ),
      );
    }
  }

  void removeImage(int index) {
    if (index < 0 || index >= state.images.length) return;
    final images = [...state.images]..removeAt(index);
    emit(state.copyWith(images: images));
  }

  /// Substitui as legendas de uma imagem com o resultado do editor de tela
  /// cheia, reaplicando os limites do §3.5.2 (máx. 5 por imagem, x/y ∈ [0,1]).
  void setCaptions(int imageIndex, List<DogPostDraftCaption> captions) {
    final image = state.images.elementAtOrNull(imageIndex);
    if (image == null) return;
    final sanitized = [
      for (final caption in captions.take(maxCaptionsPerImage))
        DogPostDraftCaption(
          text: caption.text,
          x: caption.x.clamp(0.0, 1.0),
          y: caption.y.clamp(0.0, 1.0),
        ),
    ];
    _patchImage(
      image.localId,
      (current) => current.copyWith(captions: sanitized),
    );
  }

  /// Valida o draft e cria/atualiza o post. Sucesso ⇒ `savedPost` one-shot.
  Future<void> save() async {
    final dogId = _dogId;
    if (dogId == null || state.saving) return;
    final validation = _validate();
    if (validation != null) {
      emit(state.copyWith(errorMessage: validation));
      return;
    }
    final draft = DogPostDraft(
      type: state.type,
      text: state.type.allowsText ? state.text : null,
      images: [
        for (var i = 0; i < state.images.length; i++)
          DogPostDraftImage(
            key: state.images[i].key!,
            position: i,
            captions: state.images[i].captions,
          ),
      ],
    );
    emit(state.copyWith(saving: true));
    try {
      final postId = _postId;
      final saved = postId == null
          ? await _repository.createPost(dogId, draft)
          : await _repository.updatePost(dogId, postId, draft);
      emit(state.copyWith(saving: false, savedPost: saved));
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          saving: false,
          errorMessage: dogPostErrorMessage(exception),
        ),
      );
    }
  }

  String? _validate() {
    final type = state.type;
    if (state.uploading) return 'Aguarde o envio das imagens.';
    if (type.requiresText && state.text.trim().isEmpty) {
      return 'Escreva o texto do post.';
    }
    if (type == DogPostType.carousel &&
        state.images.length < minCarouselImages) {
      return 'O carrossel precisa de pelo menos '
          '$minCarouselImages imagens.';
    }
    if (state.images.length < type.minImages) return 'Adicione uma imagem.';
    return null;
  }

  /// Atualiza uma imagem por `localId`; ignora se ela já foi removida
  /// (ex.: upload que termina depois de um remover/troca de tipo).
  void _patchImage(int localId, ComposerImage Function(ComposerImage) patch) {
    final index =
        state.images.indexWhere((image) => image.localId == localId);
    if (index == -1) return;
    final images = [...state.images];
    images[index] = patch(images[index]);
    emit(state.copyWith(images: images));
  }
}
