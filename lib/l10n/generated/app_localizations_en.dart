// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Glibusta';

  @override
  String get homeTitle => 'Home';

  @override
  String get searchTitle => 'Search';

  @override
  String get libraryTitle => 'Library';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get readerTitle => 'Reader';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get collectionsTitle => 'Collections';

  @override
  String get annotationsTitle => 'Annotations';

  @override
  String get statisticsTitle => 'Statistics';

  @override
  String get catalogTitle => 'Catalog';

  @override
  String get genresTitle => 'Genres';

  @override
  String get genreTitle => 'Genre';

  @override
  String get newLabel => 'New';

  @override
  String get popularLabel => 'Popular';

  @override
  String get popularSection => 'Popular';

  @override
  String get allGenres => 'All genres';

  @override
  String get recentlyAdded => 'Recently added';

  @override
  String get onlineCatalogs => 'Online Catalogs';

  @override
  String get filterHint => 'Filter...';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get noGenres => 'No genres';

  @override
  String get noBooksInGenre => 'No books in this genre';

  @override
  String get noRecentBooks => 'No recently added books';

  @override
  String get noBooksByAuthor => 'No books by this author';

  @override
  String get authorFallback => 'Author';

  @override
  String get categoriesLoadError => 'Failed to load categories';

  @override
  String get genresLoadError => 'Failed to load genres';

  @override
  String get genreLoadError => 'Failed to load genre';

  @override
  String get recentBooksLoadError => 'Failed to load recent books';

  @override
  String get authorLoadError => 'Failed to load author';

  @override
  String get opdsLoadError => 'Load error';

  @override
  String get opdsSearchError => 'Search error';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get collapse => 'Collapse';

  @override
  String get readMore => 'Read more';

  @override
  String get loading => 'Loading';

  @override
  String get addCatalog => 'Add catalog';

  @override
  String get nameLabel => 'Name';

  @override
  String get opdsUrlLabel => 'OPDS catalog URL';

  @override
  String get catalogSearchHint => 'Search catalog...';

  @override
  String get opdsDownloading => 'Downloading';

  @override
  String bookCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      one: '$count book',
    );
    return '$_temp0';
  }

  @override
  String bookCountRu(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      few: '$count books',
      one: '$count book',
      zero: 'no books',
    );
    return '$_temp0';
  }

  @override
  String seriesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series',
      one: '$count series',
    );
    return '$_temp0';
  }

  @override
  String pagesLabel(Object count) {
    return '$count p.';
  }

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsSource => 'Source';

  @override
  String get settingsDownloads => 'Downloads';

  @override
  String get settingsStorage => 'Library Storage';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsBaseUrl => 'Base URL';

  @override
  String get settingsMirrors => 'Mirrors';

  @override
  String get settingsNotConfigured => 'Not configured';

  @override
  String get settingsParallelDownloads => 'Parallel downloads';

  @override
  String get settingsMobileDownloads => 'Download over mobile';

  @override
  String get settingsMobileDownloadsSub => 'Wi-Fi only by default';

  @override
  String get settingsAutoResume => 'Auto-resume on Wi-Fi';

  @override
  String get settingsAutoResumeSub => 'Resume downloads when network appears';

  @override
  String get settingsStorageMode => 'Storage';

  @override
  String get settingsStorageModeDownloads => 'Downloads/Glibusta';

  @override
  String get settingsStorageModeExternal => 'Selected folder';

  @override
  String get settingsStorageModeAccessible => 'Accessible from file manager';

  @override
  String get settingsStorageModeNotSelected => 'No folder selected';

  @override
  String get settingsStorageManagement => 'Storage Management';

  @override
  String get settingsStorageManagementSub => 'Data size, cache cleanup';

  @override
  String get settingsRefreshLibrary => 'Refresh Library';

  @override
  String get settingsRefreshLibrarySub => 'Scan folder for new books';

  @override
  String get settingsTags => 'Tags';

  @override
  String get settingsTagsSub => 'Manage book tags';

  @override
  String get settingsDarkTheme => 'Dark theme';

  @override
  String get settingsDarkThemeSub => 'Use dark theme';

  @override
  String get settingsContentFilter => 'Content Filter';

  @override
  String get settingsContentFilterSub => 'Security settings';

  @override
  String get settingsFonts => 'Fonts';

  @override
  String get settingsFontsSub => 'Download additional fonts';

  @override
  String get settingsExport => 'Export Data';

  @override
  String get settingsExportSub => 'Save bookmarks, notes, quotes, collections';

  @override
  String get settingsImport => 'Import Data';

  @override
  String get settingsImportSub => 'Restore from backup file';

  @override
  String get settingsShortcuts => 'Keyboard Shortcuts';

  @override
  String get settingsShortcutsSub => 'List of key combinations';

  @override
  String get settingsDiagnostics => 'Diagnostics';

  @override
  String get settingsDiagnosticsSub => 'Debug information';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsUnknown => 'Unknown';

  @override
  String get storageTitle => 'Storage Management';

  @override
  String storageTotal(Object size) {
    return 'Total: $size';
  }

  @override
  String get storageDb => 'Database';

  @override
  String get storageBooksInternal => 'Books (internal)';

  @override
  String get storageDownloads => 'Downloads';

  @override
  String get storageCovers => 'Covers';

  @override
  String get storageCatalogCovers => 'Catalog Covers';

  @override
  String get storageCache => 'Cache';

  @override
  String get storageTemp => 'Temporary';

  @override
  String get storageActions => 'Actions';

  @override
  String get storageCleanTemp => 'Clean Temporary Files';

  @override
  String get storageCleanTempSub => 'Files older than 1 hour';

  @override
  String get storageCleanCache => 'Clean Cache';

  @override
  String get storageCleanCacheSub => 'Cache files older than 7 days';

  @override
  String get storageFindOrphans => 'Find Orphan Files';

  @override
  String get storageFindOrphansSub => 'Files without DB records';

  @override
  String get storageFindHeavy => 'Heavy Books';

  @override
  String get storageFindHeavySub => 'Books larger than 5 MB';

  @override
  String get storageCleanCatalogCovers => 'Clean Catalog Cover Cache';

  @override
  String get storageCleanCatalogCoversSub => 'Delete all cached covers';

  @override
  String get storageCleanExpiredCovers => 'Clean Expired Covers';

  @override
  String get storageCleanExpiredCoversSub => 'Covers older than 30 days';

  @override
  String get storageCleaning => 'Cleaning in progress...';

  @override
  String storageOrphansFound(Object count) {
    return '$count orphan files found';
  }

  @override
  String get storageNoOrphans => 'No orphan files found';

  @override
  String storageHeavyFound(Object count) {
    return '$count heavy books found';
  }

  @override
  String get storageNoHeavy => 'No heavy books found';

  @override
  String storageTempCleaned(Object count, Object size) {
    return 'Deleted $count files ($size)';
  }

  @override
  String storageCacheCleaned(Object count) {
    return 'Cleaned $count cache files';
  }

  @override
  String get storageCatalogCoversCleaned => 'Catalog cover cache cleared';

  @override
  String get storageExpiredCoversCleaned => 'Expired covers deleted';

  @override
  String get storageAlreadyScanning => 'Scan already in progress';

  @override
  String get storageScanning => 'Scanning folder...';

  @override
  String storageScanResult(Object imported, Object skipped) {
    return 'Imported: $imported, skipped: $skipped';
  }
}
