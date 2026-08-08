part of 'dog_post_composer_cubit.dart';

/// `loading` cobre o fetch do post na edição via deep link (sem extra).
enum DogPostComposerStatus { loading, ready, error }

class DogPostComposerState extends Equatable {
  const DogPostComposerState({
    this.status = DogPostComposerStatus.loading,
    this.message,
    this.isEditing = false,
    this.type = DogPostType.text,
    this.text = '',
    this.images = const [],
    this.saving = false,
    this.savedPost,
    this.errorMessage,
  });

  final DogPostComposerStatus status;

  /// Erro do carregamento do post em edição (estado de erro com retry).
  final String? message;

  /// Edição de post existente (`type` imutável).
  final bool isEditing;

  final DogPostType type;
  final String text;
  final List<ComposerImage> images;
  final bool saving;

  /// One-shot: post salvo (a tela fecha e o manager recarrega).
  final DogPostModel? savedPost;

  /// One-shot: validação/upload/salvamento falhou — SnackBar.
  final String? errorMessage;

  /// Algum upload em andamento (bloqueia o salvar).
  bool get uploading => images.any((image) => image.uploading);

  DogPostComposerState copyWith({
    DogPostComposerStatus? status,
    String? message,
    bool? isEditing,
    DogPostType? type,
    String? text,
    List<ComposerImage>? images,
    bool? saving,
    DogPostModel? savedPost,
    String? errorMessage,
  }) {
    return DogPostComposerState(
      status: status ?? this.status,
      message: message ?? this.message,
      isEditing: isEditing ?? this.isEditing,
      type: type ?? this.type,
      text: text ?? this.text,
      images: images ?? this.images,
      saving: saving ?? this.saving,
      savedPost: savedPost,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        message,
        isEditing,
        type,
        text,
        images,
        saving,
        savedPost,
        errorMessage,
      ];
}

/// Imagem do draft no composer: preview local ([bytes]) ou remota ([url]);
/// [key] só existe após o upload presigned terminar.
class ComposerImage extends Equatable {
  const ComposerImage({
    required this.localId,
    this.key,
    this.url,
    this.bytes,
    this.uploading = false,
    this.captions = const [],
  });

  /// Identidade local estável (uploads concorrentes/remoções).
  final int localId;

  final String? key;
  final String? url;
  final Uint8List? bytes;
  final bool uploading;
  final List<DogPostDraftCaption> captions;

  ComposerImage copyWith({
    String? key,
    String? url,
    bool? uploading,
    List<DogPostDraftCaption>? captions,
  }) {
    return ComposerImage(
      localId: localId,
      key: key ?? this.key,
      url: url ?? this.url,
      bytes: bytes,
      uploading: uploading ?? this.uploading,
      captions: captions ?? this.captions,
    );
  }

  @override
  List<Object?> get props => [localId, key, url, bytes, uploading, captions];
}
