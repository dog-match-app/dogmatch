import 'package:dogmatch/features/dogs/data/models/dog_post_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_draft.dart';

/// Contrato dos posts da página do cão (ARCHITECTURE §3.5.2/§4).
abstract class DogPostsRepository {
  /// `GET /dogs/:id/posts` (createdAt desc).
  Future<List<DogPostModel>> getPosts(String dogId);

  /// `POST /dogs/:id/posts` — 400 `POST_LIMIT_REACHED` acima de 10 posts.
  Future<DogPostModel> createPost(String dogId, DogPostDraft draft);

  /// `PATCH /dogs/:id/posts/:postId` — substitui o conteúdo; `type` imutável.
  Future<DogPostModel> updatePost(
    String dogId,
    String postId,
    DogPostDraft draft,
  );

  /// `DELETE /dogs/:id/posts/:postId`.
  Future<void> deletePost(String dogId, String postId);
}
