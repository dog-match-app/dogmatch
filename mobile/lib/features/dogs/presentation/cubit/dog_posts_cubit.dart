import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/dogs/data/models/dog_post_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_rules.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_posts_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'dog_posts_state.dart';

/// Converte erros da API de posts em mensagem pronta para a UI: o
/// `400 POST_LIMIT_REACHED` do backend vira [postLimitMessage]; os demais
/// mantêm a mensagem PT-BR da [ApiException].
String dogPostErrorMessage(ApiException exception) {
  if (exception.backendCode == 'POST_LIMIT_REACHED' ||
      exception.message.contains('POST_LIMIT_REACHED')) {
    return postLimitMessage;
  }
  return exception.message;
}

/// Lista os posts de um cão e remove com atualização otimista (a lista é
/// restaurada se o DELETE falhar). Expõe `count`/`canAddMore` (limite 10).
@injectable
class DogPostsCubit extends Cubit<DogPostsState> {
  DogPostsCubit(this._repository) : super(const DogPostsState());

  final DogPostsRepository _repository;

  String? _dogId;

  Future<void> load(String dogId) async {
    _dogId = dogId;
    emit(state.copyWith(status: DogPostsStatus.loading));
    try {
      final posts = await _repository.getPosts(dogId);
      // Garante a ordem do contrato (createdAt desc) mesmo se a API variar.
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(state.copyWith(status: DogPostsStatus.success, posts: posts));
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          status: DogPostsStatus.error,
          message: dogPostErrorMessage(exception),
        ),
      );
    }
  }

  /// Remoção otimista: tira o post da lista imediatamente e restaura a
  /// lista anterior (com erro one-shot) se a API falhar.
  Future<void> delete(String postId) async {
    final dogId = _dogId;
    if (dogId == null) return;
    final previous = state.posts;
    emit(
      state.copyWith(
        posts: previous.where((post) => post.id != postId).toList(),
      ),
    );
    try {
      await _repository.deletePost(dogId, postId);
    } on ApiException catch (exception) {
      emit(
        state.copyWith(
          posts: previous,
          actionError: dogPostErrorMessage(exception),
        ),
      );
    }
  }
}
