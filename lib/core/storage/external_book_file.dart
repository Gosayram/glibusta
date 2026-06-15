final class ExternalBookFile {
  const ExternalBookFile({
    required this.uri,
    required this.name,
    required this.size,
    required this.extension,
    this.mimeType,
    this.lastModified,
  });

  final String uri;
  final String name;
  final int size;
  final String extension;
  final String? mimeType;
  final int? lastModified;
}
