import 'package:dogmatch/features/search/data/models/search_card_model.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'search_result_model.g.dart';

/// `SearchResultDto` — página de resultados de `GET /discovery/search`.
@JsonSerializable()
class SearchResultModel extends Equatable {
  const SearchResultModel({
    this.items = const [],
    required this.total,
    required this.page,
    required this.pageCount,
  });

  factory SearchResultModel.fromJson(Map<String, dynamic> json) =>
      _$SearchResultModelFromJson(json);

  final List<SearchCardModel> items;
  final int total;
  final int page;
  final int pageCount;

  /// Ainda há páginas a carregar depois desta.
  bool get hasMore => page < pageCount;

  Map<String, dynamic> toJson() => _$SearchResultModelToJson(this);

  @override
  List<Object?> get props => [items, total, page, pageCount];
}
