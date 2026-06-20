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
