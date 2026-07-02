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

  @override
  String get settingsAccount => 'Аккаунт';

  @override
  String get settingsSource => 'Источник';

  @override
  String get settingsDownloads => 'Загрузки';

  @override
  String get settingsStorage => 'Хранилище библиотеки';

  @override
  String get settingsAppearance => 'Отображение';

  @override
  String get settingsData => 'Данные';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get settingsBaseUrl => 'Базовый URL';

  @override
  String get settingsMirrors => 'Зеркала';

  @override
  String get settingsNotConfigured => 'Не настроены';

  @override
  String get settingsParallelDownloads => 'Параллельные загрузки';

  @override
  String get settingsMobileDownloads => 'Скачивать через мобильную сеть';

  @override
  String get settingsMobileDownloadsSub => 'По умолчанию только Wi-Fi';

  @override
  String get settingsAutoResume => 'Авто-продолжение при Wi-Fi';

  @override
  String get settingsAutoResumeSub => 'Возобновлять загрузки при появлении сети';

  @override
  String get settingsStorageMode => 'Хранилище';

  @override
  String get settingsStorageModeDownloads => 'Downloads/Glibusta';

  @override
  String get settingsStorageModeExternal => 'Выбранная папка';

  @override
  String get settingsStorageModeAccessible => 'Доступна из файлового менеджера';

  @override
  String get settingsStorageModeNotSelected => 'Папка не выбрана';

  @override
  String get settingsStorageManagement => 'Управление хранилищем';

  @override
  String get settingsStorageManagementSub => 'Размер данных, очистка кеша';

  @override
  String get settingsStoragePermission => 'Доступ к файлам';

  @override
  String get settingsStoragePermissionSub => 'Разрешить чтение из папки загрузок';

  @override
  String get settingsStoragePermissionGranted => 'Доступ к файлам уже предоставлен';

  @override
  String get settingsStoragePermissionOpenSettings =>
      'Откройте настройки и разрешите доступ к файлам';

  @override
  String get settingsRefreshLibrary => 'Обновить библиотеку';

  @override
  String get settingsRefreshLibrarySub => 'Просканировать папку на новые книги';

  @override
  String get settingsTags => 'Теги';

  @override
  String get settingsTagsSub => 'Управление тегами книг';

  @override
  String get settingsDarkTheme => 'Тёмная тема';

  @override
  String get settingsDarkThemeSub => 'Использовать тёмную тему';

  @override
  String get settingsContentFilter => 'Фильтр контента';

  @override
  String get settingsContentFilterSub => 'Настройка безопасности';

  @override
  String get settingsFonts => 'Шрифты';

  @override
  String get settingsFontsSub => 'Скачать дополнительные шрифты';

  @override
  String get settingsExport => 'Экспорт данных';

  @override
  String get settingsExportSub => 'Сохранить закладки, заметки, цитаты, коллекции';

  @override
  String get settingsImport => 'Импорт данных';

  @override
  String get settingsImportSub => 'Восстановить из файла резервной копии';

  @override
  String get settingsShortcuts => 'Горячие клавиши';

  @override
  String get settingsShortcutsSub => 'Список сочетаний клавиш';

  @override
  String get settingsDiagnostics => 'Диагностика';

  @override
  String get settingsDiagnosticsSub => 'Информация для отладки';

  @override
  String get settingsVersion => 'Версия';

  @override
  String get settingsUnknown => 'Неизвестно';

  @override
  String get storageTitle => 'Управление хранилищем';

  @override
  String storageTotal(Object size) {
    return 'Всего: $size';
  }

  @override
  String get storageDb => 'База данных';

  @override
  String get storageBooksInternal => 'Книги (внутр.)';

  @override
  String get storageDownloads => 'Загрузки';

  @override
  String get storageCovers => 'Обложки';

  @override
  String get storageCatalogCovers => 'Обложки каталога';

  @override
  String get storageCache => 'Кеш';

  @override
  String get storageTemp => 'Временные';

  @override
  String get storageActions => 'Действия';

  @override
  String get storageCleanTemp => 'Очистить временные файлы';

  @override
  String get storageCleanTempSub => 'Файлы старше 1 часа';

  @override
  String get storageCleanCache => 'Очистить кеш';

  @override
  String get storageCleanCacheSub => 'Файлы кеша старше 7 дней';

  @override
  String get storageFindOrphans => 'Найти сиротские файлы';

  @override
  String get storageFindOrphansSub => 'Файлы книг без записи в БД';

  @override
  String get storageFindHeavy => 'Тяжёлые книги';

  @override
  String get storageFindHeavySub => 'Книги больше 5 МБ';

  @override
  String get storageCleanCatalogCovers => 'Очистить кеш обложек каталога';

  @override
  String get storageCleanCatalogCoversSub => 'Удалить все кешированные обложки';

  @override
  String get storageCleanExpiredCovers => 'Очистить устаревшие обложки';

  @override
  String get storageCleanExpiredCoversSub => 'Обложки старше 30 дней';

  @override
  String get storageCleaning => 'Выполняется очистка...';

  @override
  String storageOrphansFound(Object count) {
    return 'Найдено сиротских файлов: $count';
  }

  @override
  String get storageNoOrphans => 'Сиротские файлы не найдены';

  @override
  String storageHeavyFound(Object count) {
    return 'Найдено тяжёлых книг: $count';
  }

  @override
  String get storageNoHeavy => 'Тяжёлых книг не найдено';

  @override
  String storageTempCleaned(Object count, Object size) {
    return 'Удалено файлов: $count ($size)';
  }

  @override
  String storageCacheCleaned(Object count) {
    return 'Очищено файлов кеша: $count';
  }

  @override
  String get storageCatalogCoversCleaned => 'Кеш обложек каталога очищен';

  @override
  String get storageExpiredCoversCleaned => 'Устаревшие обложки удалены';

  @override
  String get storageAlreadyScanning => 'Сканирование уже выполняется';

  @override
  String get storageScanning => 'Сканирование папки...';

  @override
  String storageScanResult(Object imported, Object skipped) {
    return 'Импортировано: $imported, пропущено: $skipped';
  }
}
