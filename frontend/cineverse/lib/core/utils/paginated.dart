/// Envelope de paginação devolvido por toda listagem da API:
/// `{ items, page, pageSize, total, totalPages }`.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonItem,
  ) {
    return Paginated(
      items: (json['items'] as List).map(fromJsonItem).toList(),
      page: json['page'] as int,
      pageSize: json['pageSize'] as int,
      total: json['total'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasNextPage => page < totalPages;
}
