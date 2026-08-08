part of 'dog_posts_cubit.dart';

enum DogPostsStatus { initial, loading, success, error }

class DogPostsState extends Equatable {
  const DogPostsState({
    this.status = DogPostsStatus.initial,
    this.posts = const [],
    this.message,
    this.actionError,
  });

  final DogPostsStatus status;

  /// Posts em `createdAt desc`.
  final List<DogPostModel> posts;

  /// Erro do carregamento (estado de erro com retry).
  final String? message;

  /// One-shot: falha de uma ação (ex.: delete revertido) — SnackBar.
  final String? actionError;

  int get count => posts.length;

  /// Ainda abaixo do limite de [maxPostsPerDog] posts.
  bool get canAddMore => posts.length < maxPostsPerDog;

  DogPostsState copyWith({
    DogPostsStatus? status,
    List<DogPostModel>? posts,
    String? message,
    String? actionError,
  }) {
    return DogPostsState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      message: message,
      actionError: actionError,
    );
  }

  @override
  List<Object?> get props => [status, posts, message, actionError];
}
