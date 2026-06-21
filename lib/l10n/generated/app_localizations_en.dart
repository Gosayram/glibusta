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
}
