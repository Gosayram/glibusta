import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/http/http_client.dart';

part 'book_comments_service.g.dart';

@riverpod
BookCommentsService bookCommentsService(Ref ref) {
  final client = ref.watch(httpClientProvider);
  return BookCommentsService(client);
}

class BookComment {
  final String id;
  final String author;
  final String text;
  final DateTime? createdAt;

  const BookComment({
    required this.id,
    required this.author,
    required this.text,
    this.createdAt,
  });
}

class BookCommentsService {
  final HttpClient _client;

  BookCommentsService(this._client);

  Future<List<BookComment>> getComments(String bookId) async {
    try {
      final html = await _client.getWithMirror('/b/$bookId');
      return _parseComments(html);
    } on Object catch (_) {
      return const [];
    }
  }

  Future<bool> postComment({
    required String bookId,
    required String body,
    required Map<String, String> cookies,
  }) async {
    try {
      final html = await _client.getWithMirror('/b/$bookId');
      final formBuildId = _extractFormValue(html, 'form_build_id');
      final formId = _extractFormValue(html, 'form_id');
      final formToken = _extractFormValue(html, 'form_token');

      if (formBuildId == null) return false;

      final formData = {
        'body[0][value]': body,
        'body[0][format]': 'filtered_html',
        'form_build_id': formBuildId,
        'form_id': formId ?? 'comment_node_book_form',
      };
      if (formToken != null) {
        formData['form_token'] = formToken;
      }

      final cookieHeader = cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

      await _client.dio.post<String>(
        '/comment/add/node/book',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {'Cookie': cookieHeader},
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  List<BookComment> _parseComments(String html) {
    final doc = html_parser.parse(html);
    final comments = <BookComment>[];

    final commentNodes = doc.querySelectorAll('.comment, .comment-wrapper, .indented');
    var idx = 0;
    for (final node in commentNodes) {
      final authorEl = node.querySelector(
        '.comment-author a, .author a, .username, .submitted a',
      );
      final bodyEl = node.querySelector(
        '.comment-body .field-item, .comment-content, .comment .content',
      );
      final dateEl = node.querySelector('.comment-time, .submitted, time');

      final author = authorEl?.text.trim() ?? 'Аноним';
      final body = bodyEl?.text.trim() ?? '';
      if (body.isEmpty) continue;

      DateTime? createdAt;
      if (dateEl != null) {
        createdAt = DateTime.tryParse(dateEl.attributes['datetime'] ?? '');
      }

      comments.add(
        BookComment(
          id: 'comment_${idx++}',
          author: author,
          text: body,
          createdAt: createdAt,
        ),
      );
    }
    return comments;
  }

  String? _extractFormValue(String html, String fieldName) {
    final regex = RegExp(
      '<input[^>]*name="$fieldName"[^>]*value="([^"]*)"',
      caseSensitive: false,
    );
    final match = regex.firstMatch(html);
    return match?.group(1);
  }
}
