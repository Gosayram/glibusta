import 'book.dart';

enum DownloadStatus { queued, running, paused, completed, failed, canceled }

class DownloadTask {
  final String id;
  final String bookId;
  final String? bookTitle;
  final BookFormat format;
  final String sourceUrl;
  final String? targetPath;
  final DownloadStatus status;
  final int? downloadedBytes;
  final int? totalBytes;

  const DownloadTask({
    required this.id,
    required this.bookId,
    this.bookTitle,
    required this.format,
    required this.sourceUrl,
    required this.targetPath,
    required this.status,
    required this.downloadedBytes,
    required this.totalBytes,
  });
}

class BookDetails {
  final Book book;
  final String? description;
  final List<BookFormat> availableFormats;
  final List<String> downloadUrls;

  const BookDetails({
    required this.book,
    required this.description,
    required this.availableFormats,
    required this.downloadUrls,
  });
}
