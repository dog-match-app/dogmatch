import 'package:dio/dio.dart';
import 'package:dogmatch/core/error/api_exception.dart';
import 'package:dogmatch/features/dogs/data/models/dog_post_model.dart';
import 'package:dogmatch/features/dogs/domain/entities/dog_post_draft.dart';
import 'package:dogmatch/features/dogs/domain/repositories/dog_posts_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: DogPostsRepository)
class DogPostsRepositoryImpl implements DogPostsRepository {
  DogPostsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<DogPostModel>> getPosts(String dogId) {
    return guardApi(() async {
      final response = await _dio.get<List<dynamic>>('/dogs/$dogId/posts');
      return (response.data ?? [])
          .map((json) => DogPostModel.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<DogPostModel> createPost(String dogId, DogPostDraft draft) {
    return guardApi(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/dogs/$dogId/posts',
        data: draft.toPayload(includeType: true),
      );
      return DogPostModel.fromJson(response.data!);
    });
  }

  @override
  Future<DogPostModel> updatePost(
    String dogId,
    String postId,
    DogPostDraft draft,
  ) {
    return guardApi(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/dogs/$dogId/posts/$postId',
        data: draft.toPayload(includeType: false),
      );
      return DogPostModel.fromJson(response.data!);
    });
  }

  @override
  Future<void> deletePost(String dogId, String postId) {
    return guardApi(() async {
      await _dio.delete<void>('/dogs/$dogId/posts/$postId');
    });
  }
}
