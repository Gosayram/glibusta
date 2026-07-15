/// Canonical list of all book file extensions the app can open or scan for.
///
/// This is the single source of truth. Every file-picker, folder-scan,
/// and share-handler filter must reference this list instead of
/// maintaining a private copy.
const List<String> supportedBookExtensions = [
  'epub',
  'fb2',
  'zip',
  'txt',
  'rtf',
  'pdf',
  'mobi',
  'azw',
  'azw3',
  'prc',
  'djvu',
  'djv',
  'docx',
  'docm',
  'cbz',
  'cbr',
];
