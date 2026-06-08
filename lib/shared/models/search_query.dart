enum DownloadStatus { queued, running, paused, completed, failed, canceled }

class SearchQuery {
  final String query;
  final String? author;
  final String? title;
  final String? series;
  final String? genre;
  final int page;

  const SearchQuery({
    required this.query,
    this.author,
    this.title,
    this.series,
    this.genre,
    this.page = 0,
  });
}

class SearchResultPage {
  final List<dynamic> books;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;

  const SearchResultPage({
    required this.books,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
  });
}