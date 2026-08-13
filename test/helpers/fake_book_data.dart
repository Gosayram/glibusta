import 'dart:math';

import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';

class FakeBookData {
  FakeBookData._();

  static final _random = Random(42);

  static const _titles = [
    'Война и мир',
    'Преступление и наказание',
    'Мастер и Маргарита',
    'Тихий Дон',
    'Доктор Живаго',
    'Отцы и дети',
    'Лолита',
    'Обломов',
    'Анна Каренина',
    'Евгений Онегин',
    'Герой нашего времени',
    'Двенадцать стульев',
    'Собачье сердце',
    'Мёртвые души',
    'Идиот',
    'Братья Карамазовы',
    'Вишнёвый сад',
    'Три сестры',
    'Ревизор',
    'Игрок',
  ];

  static const _authors = [
    'Лев Толстой',
    'Фёдор Достоевский',
    'Михаил Булгаков',
    'Михаил Шолохов',
    'Борис Пастернак',
    'Иван Тургенев',
    'Владимир Набоков',
    'Иван Гончаров',
    'Александр Пушкин',
    'Михаил Лермонтов',
    'Илья Ильф',
    'Евгений Петров',
    'Михаил Зощенко',
    'Николай Гоголь',
    'Антон Чехов',
    'Николай Лесков',
  ];

  static String title() => _titles[_random.nextInt(_titles.length)];

  static String author() => _authors[_random.nextInt(_authors.length)];

  static List<String> authors({int count = 1}) {
    final n = count.clamp(1, _authors.length);
    final shuffled = [..._authors]..shuffle(_random);
    return shuffled.sublist(0, n);
  }

  static String description() {
    final words = [
      'Захватывающий',
      'Глубокий',
      'Трогательный',
      'Юмористический',
      'Драматический',
      'Философский',
    ];
    return '${words[_random.nextInt(words.length)]} роман о жизни и судьбе.';
  }

  static NormalizedBook book({
    String? title,
    List<String>? authors,
    int chapterCount = 3,
    int blocksPerChapter = 5,
    int authorCount = 1,
  }) {
    final t = title ?? FakeBookData.title();
    final a = authors ?? FakeBookData.authors(count: authorCount);
    final chapters = <ReaderChapter>[];
    for (var i = 0; i < chapterCount; i++) {
      final blocks = <ReaderBlock>[];
      for (var j = 0; j < blocksPerChapter; j++) {
        blocks.add(
          ReaderBlock(
            index: j,
            text: 'Абзац ${j + 1} главы ${i + 1}. ${description()}',
          ),
        );
      }
      chapters.add(ReaderChapter(index: i, title: 'Глава ${i + 1}', blocks: blocks));
    }
    return NormalizedBook(
      id: 'fake_${_random.nextInt(999999)}',
      title: t,
      authors: a,
      description: description(),
      chapters: chapters,
    );
  }
}
