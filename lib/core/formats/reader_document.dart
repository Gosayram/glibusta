import '../../features/reader/data/parsers/normalized_book.dart';
import '../../shared/models/book.dart';

final class ReaderDocument {
  const ReaderDocument({
    required this.title,
    required this.format,
    required this.chapters,
    this.authors = const [],
    this.description,
  });

  final String title;
  final BookFormat format;
  final List<ReaderChapter> chapters;
  final List<String> authors;
  final String? description;

  NormalizedBook toNormalizedBook(String id) {
    return NormalizedBook(
      id: id,
      title: title,
      authors: authors,
      description: description,
      chapters: chapters,
      metadata: {'format': format.name},
    );
  }
}
