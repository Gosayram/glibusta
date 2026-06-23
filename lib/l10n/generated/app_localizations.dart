import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart' deferred as app_localizations_en;
import 'app_localizations_ru.dart' deferred as app_localizations_ru;

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('ru')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Glibusta'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @downloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsTitle;

  /// No description provided for @readerTitle.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get readerTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @collectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collectionsTitle;

  /// No description provided for @annotationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Annotations'**
  String get annotationsTitle;

  /// No description provided for @statisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statisticsTitle;

  /// No description provided for @catalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get catalogTitle;

  /// No description provided for @genresTitle.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get genresTitle;

  /// No description provided for @genreTitle.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genreTitle;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @popularLabel.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popularLabel;

  /// No description provided for @popularSection.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popularSection;

  /// No description provided for @allGenres.
  ///
  /// In en, this message translates to:
  /// **'All genres'**
  String get allGenres;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get recentlyAdded;

  /// No description provided for @onlineCatalogs.
  ///
  /// In en, this message translates to:
  /// **'Online Catalogs'**
  String get onlineCatalogs;

  /// No description provided for @filterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter...'**
  String get filterHint;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

  /// No description provided for @noGenres.
  ///
  /// In en, this message translates to:
  /// **'No genres'**
  String get noGenres;

  /// No description provided for @noBooksInGenre.
  ///
  /// In en, this message translates to:
  /// **'No books in this genre'**
  String get noBooksInGenre;

  /// No description provided for @noRecentBooks.
  ///
  /// In en, this message translates to:
  /// **'No recently added books'**
  String get noRecentBooks;

  /// No description provided for @noBooksByAuthor.
  ///
  /// In en, this message translates to:
  /// **'No books by this author'**
  String get noBooksByAuthor;

  /// No description provided for @authorFallback.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get authorFallback;

  /// No description provided for @categoriesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load categories'**
  String get categoriesLoadError;

  /// No description provided for @genresLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load genres'**
  String get genresLoadError;

  /// No description provided for @genreLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load genre'**
  String get genreLoadError;

  /// No description provided for @recentBooksLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load recent books'**
  String get recentBooksLoadError;

  /// No description provided for @authorLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load author'**
  String get authorLoadError;

  /// No description provided for @opdsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Load error'**
  String get opdsLoadError;

  /// No description provided for @opdsSearchError.
  ///
  /// In en, this message translates to:
  /// **'Search error'**
  String get opdsSearchError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get readMore;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @addCatalog.
  ///
  /// In en, this message translates to:
  /// **'Add catalog'**
  String get addCatalog;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @opdsUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'OPDS catalog URL'**
  String get opdsUrlLabel;

  /// No description provided for @catalogSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search catalog...'**
  String get catalogSearchHint;

  /// No description provided for @opdsDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get opdsDownloading;

  /// No description provided for @bookCount.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{{count} book} other{{count} books}}'**
  String bookCount(num count);

  /// No description provided for @bookCountRu.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =0{no books} one{{count} book} few{{count} books} other{{count} books}}'**
  String bookCountRu(num count);

  /// No description provided for @seriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{{count} series} other{{count} series}}'**
  String seriesCount(num count);

  /// No description provided for @pagesLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} p.'**
  String pagesLabel(Object count);

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get settingsSource;

  /// No description provided for @settingsDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get settingsDownloads;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Library Storage'**
  String get settingsStorage;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get settingsBaseUrl;

  /// No description provided for @settingsMirrors.
  ///
  /// In en, this message translates to:
  /// **'Mirrors'**
  String get settingsMirrors;

  /// No description provided for @settingsNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get settingsNotConfigured;

  /// No description provided for @settingsParallelDownloads.
  ///
  /// In en, this message translates to:
  /// **'Parallel downloads'**
  String get settingsParallelDownloads;

  /// No description provided for @settingsMobileDownloads.
  ///
  /// In en, this message translates to:
  /// **'Download over mobile'**
  String get settingsMobileDownloads;

  /// No description provided for @settingsMobileDownloadsSub.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only by default'**
  String get settingsMobileDownloadsSub;

  /// No description provided for @settingsAutoResume.
  ///
  /// In en, this message translates to:
  /// **'Auto-resume on Wi-Fi'**
  String get settingsAutoResume;

  /// No description provided for @settingsAutoResumeSub.
  ///
  /// In en, this message translates to:
  /// **'Resume downloads when network appears'**
  String get settingsAutoResumeSub;

  /// No description provided for @settingsStorageMode.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorageMode;

  /// No description provided for @settingsStorageModeDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads/Glibusta'**
  String get settingsStorageModeDownloads;

  /// No description provided for @settingsStorageModeExternal.
  ///
  /// In en, this message translates to:
  /// **'Selected folder'**
  String get settingsStorageModeExternal;

  /// No description provided for @settingsStorageModeAccessible.
  ///
  /// In en, this message translates to:
  /// **'Accessible from file manager'**
  String get settingsStorageModeAccessible;

  /// No description provided for @settingsStorageModeNotSelected.
  ///
  /// In en, this message translates to:
  /// **'No folder selected'**
  String get settingsStorageModeNotSelected;

  /// No description provided for @settingsStorageManagement.
  ///
  /// In en, this message translates to:
  /// **'Storage Management'**
  String get settingsStorageManagement;

  /// No description provided for @settingsStorageManagementSub.
  ///
  /// In en, this message translates to:
  /// **'Data size, cache cleanup'**
  String get settingsStorageManagementSub;

  /// No description provided for @settingsRefreshLibrary.
  ///
  /// In en, this message translates to:
  /// **'Refresh Library'**
  String get settingsRefreshLibrary;

  /// No description provided for @settingsRefreshLibrarySub.
  ///
  /// In en, this message translates to:
  /// **'Scan folder for new books'**
  String get settingsRefreshLibrarySub;

  /// No description provided for @settingsTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get settingsTags;

  /// No description provided for @settingsTagsSub.
  ///
  /// In en, this message translates to:
  /// **'Manage book tags'**
  String get settingsTagsSub;

  /// No description provided for @settingsDarkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get settingsDarkTheme;

  /// No description provided for @settingsDarkThemeSub.
  ///
  /// In en, this message translates to:
  /// **'Use dark theme'**
  String get settingsDarkThemeSub;

  /// No description provided for @settingsContentFilter.
  ///
  /// In en, this message translates to:
  /// **'Content Filter'**
  String get settingsContentFilter;

  /// No description provided for @settingsContentFilterSub.
  ///
  /// In en, this message translates to:
  /// **'Security settings'**
  String get settingsContentFilterSub;

  /// No description provided for @settingsFonts.
  ///
  /// In en, this message translates to:
  /// **'Fonts'**
  String get settingsFonts;

  /// No description provided for @settingsFontsSub.
  ///
  /// In en, this message translates to:
  /// **'Download additional fonts'**
  String get settingsFontsSub;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get settingsExport;

  /// No description provided for @settingsExportSub.
  ///
  /// In en, this message translates to:
  /// **'Save bookmarks, notes, quotes, collections'**
  String get settingsExportSub;

  /// No description provided for @settingsImport.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get settingsImport;

  /// No description provided for @settingsImportSub.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup file'**
  String get settingsImportSub;

  /// No description provided for @settingsShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get settingsShortcuts;

  /// No description provided for @settingsShortcutsSub.
  ///
  /// In en, this message translates to:
  /// **'List of key combinations'**
  String get settingsShortcutsSub;

  /// No description provided for @settingsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnostics;

  /// No description provided for @settingsDiagnosticsSub.
  ///
  /// In en, this message translates to:
  /// **'Debug information'**
  String get settingsDiagnosticsSub;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get settingsUnknown;

  /// No description provided for @storageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage Management'**
  String get storageTitle;

  /// No description provided for @storageTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {size}'**
  String storageTotal(Object size);

  /// No description provided for @storageDb.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get storageDb;

  /// No description provided for @storageBooksInternal.
  ///
  /// In en, this message translates to:
  /// **'Books (internal)'**
  String get storageBooksInternal;

  /// No description provided for @storageDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get storageDownloads;

  /// No description provided for @storageCovers.
  ///
  /// In en, this message translates to:
  /// **'Covers'**
  String get storageCovers;

  /// No description provided for @storageCatalogCovers.
  ///
  /// In en, this message translates to:
  /// **'Catalog Covers'**
  String get storageCatalogCovers;

  /// No description provided for @storageCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get storageCache;

  /// No description provided for @storageTemp.
  ///
  /// In en, this message translates to:
  /// **'Temporary'**
  String get storageTemp;

  /// No description provided for @storageActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get storageActions;

  /// No description provided for @storageCleanTemp.
  ///
  /// In en, this message translates to:
  /// **'Clean Temporary Files'**
  String get storageCleanTemp;

  /// No description provided for @storageCleanTempSub.
  ///
  /// In en, this message translates to:
  /// **'Files older than 1 hour'**
  String get storageCleanTempSub;

  /// No description provided for @storageCleanCache.
  ///
  /// In en, this message translates to:
  /// **'Clean Cache'**
  String get storageCleanCache;

  /// No description provided for @storageCleanCacheSub.
  ///
  /// In en, this message translates to:
  /// **'Cache files older than 7 days'**
  String get storageCleanCacheSub;

  /// No description provided for @storageFindOrphans.
  ///
  /// In en, this message translates to:
  /// **'Find Orphan Files'**
  String get storageFindOrphans;

  /// No description provided for @storageFindOrphansSub.
  ///
  /// In en, this message translates to:
  /// **'Files without DB records'**
  String get storageFindOrphansSub;

  /// No description provided for @storageFindHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy Books'**
  String get storageFindHeavy;

  /// No description provided for @storageFindHeavySub.
  ///
  /// In en, this message translates to:
  /// **'Books larger than 5 MB'**
  String get storageFindHeavySub;

  /// No description provided for @storageCleanCatalogCovers.
  ///
  /// In en, this message translates to:
  /// **'Clean Catalog Cover Cache'**
  String get storageCleanCatalogCovers;

  /// No description provided for @storageCleanCatalogCoversSub.
  ///
  /// In en, this message translates to:
  /// **'Delete all cached covers'**
  String get storageCleanCatalogCoversSub;

  /// No description provided for @storageCleanExpiredCovers.
  ///
  /// In en, this message translates to:
  /// **'Clean Expired Covers'**
  String get storageCleanExpiredCovers;

  /// No description provided for @storageCleanExpiredCoversSub.
  ///
  /// In en, this message translates to:
  /// **'Covers older than 30 days'**
  String get storageCleanExpiredCoversSub;

  /// No description provided for @storageCleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning in progress...'**
  String get storageCleaning;

  /// No description provided for @storageOrphansFound.
  ///
  /// In en, this message translates to:
  /// **'{count} orphan files found'**
  String storageOrphansFound(Object count);

  /// No description provided for @storageNoOrphans.
  ///
  /// In en, this message translates to:
  /// **'No orphan files found'**
  String get storageNoOrphans;

  /// No description provided for @storageHeavyFound.
  ///
  /// In en, this message translates to:
  /// **'{count} heavy books found'**
  String storageHeavyFound(Object count);

  /// No description provided for @storageNoHeavy.
  ///
  /// In en, this message translates to:
  /// **'No heavy books found'**
  String get storageNoHeavy;

  /// No description provided for @storageTempCleaned.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} files ({size})'**
  String storageTempCleaned(Object count, Object size);

  /// No description provided for @storageCacheCleaned.
  ///
  /// In en, this message translates to:
  /// **'Cleaned {count} cache files'**
  String storageCacheCleaned(Object count);

  /// No description provided for @storageCatalogCoversCleaned.
  ///
  /// In en, this message translates to:
  /// **'Catalog cover cache cleared'**
  String get storageCatalogCoversCleaned;

  /// No description provided for @storageExpiredCoversCleaned.
  ///
  /// In en, this message translates to:
  /// **'Expired covers deleted'**
  String get storageExpiredCoversCleaned;

  /// No description provided for @storageAlreadyScanning.
  ///
  /// In en, this message translates to:
  /// **'Scan already in progress'**
  String get storageAlreadyScanning;

  /// No description provided for @storageScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning folder...'**
  String get storageScanning;

  /// No description provided for @storageScanResult.
  ///
  /// In en, this message translates to:
  /// **'Imported: {imported}, skipped: {skipped}'**
  String storageScanResult(Object imported, Object skipped);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return lookupAppLocalizations(locale);
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

Future<AppLocalizations> lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return app_localizations_en.loadLibrary().then(
        (dynamic _) => app_localizations_en.AppLocalizationsEn(),
      );
    case 'ru':
      return app_localizations_ru.loadLibrary().then(
        (dynamic _) => app_localizations_ru.AppLocalizationsRu(),
      );
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
