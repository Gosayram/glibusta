// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Glibusta';

  @override
  String get homeTitle => 'Главная';

  @override
  String get searchTitle => 'Поиск';

  @override
  String get libraryTitle => 'Библиотека';

  @override
  String get downloadsTitle => 'Загрузки';

  @override
  String get readerTitle => 'Читалка';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get collectionsTitle => 'Коллекции';

  @override
  String get annotationsTitle => 'Аннотации';

  @override
  String get statisticsTitle => 'Статистика';

  @override
  String get catalogTitle => 'Каталог';

  @override
  String get genresTitle => 'Жанры';

  @override
  String get genreTitle => 'Жанр';

  @override
  String get newLabel => 'Новые';

  @override
  String get popularLabel => 'Популярные';

  @override
  String get popularSection => 'Популярное';

  @override
  String get allGenres => 'Все жанры';

  @override
  String get recentlyAdded => 'Недавно добавленные';

  @override
  String get onlineCatalogs => 'Online Catalogs';

  @override
  String get filterHint => 'Фильтр...';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get noGenres => 'Нет жанров';

  @override
  String get noBooksInGenre => 'Нет книг в этом жанре';

  @override
  String get noRecentBooks => 'Нет недавно добавленных книг';

  @override
  String get noBooksByAuthor => 'Нет книг у этого автора';

  @override
  String get authorFallback => 'Автор';

  @override
  String get categoriesLoadError => 'Не удалось загрузить категории';

  @override
  String get genresLoadError => 'Ошибка загрузки жанров';

  @override
  String get genreLoadError => 'Не удалось загрузить жанр';

  @override
  String get recentBooksLoadError => 'Не удалось загрузить недавние книги';

  @override
  String get authorLoadError => 'Не удалось загрузить автора';

  @override
  String get opdsLoadError => 'Ошибка загрузки';

  @override
  String get opdsSearchError => 'Ошибка поиска';

  @override
  String get retry => 'Повторить';

  @override
  String get cancel => 'Отмена';

  @override
  String get add => 'Добавить';

  @override
  String get collapse => 'Свернуть';

  @override
  String get readMore => 'Подробнее';

  @override
  String get loading => 'Загрузка';

  @override
  String get addCatalog => 'Добавить каталог';

  @override
  String get nameLabel => 'Название';

  @override
  String get opdsUrlLabel => 'URL OPDS каталога';

  @override
  String get catalogSearchHint => 'Поиск в каталоге...';

  @override
  String get opdsDownloading => 'Загрузка';

  @override
  String bookCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count книг',
      many: '$count книг',
      few: '$count книги',
      one: '$count книга',
      zero: 'нет книг',
    );
    return '$_temp0';
  }

  @override
  String bookCountRu(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count книг',
      many: '$count книг',
      few: '$count книги',
      one: '$count книга',
      zero: 'нет книг',
    );
    return '$_temp0';
  }

  @override
  String seriesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count циклов',
      many: '$count циклов',
      few: '$count цикла',
      one: '$count цикл',
    );
    return '$_temp0';
  }

  @override
  String pagesLabel(Object count) {
    return '$count с.';
  }
}
