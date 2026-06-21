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
    } on DioException catch (_) {
      return const [];
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
    } on DioException catch (_) {
      return false;
    } on Object catch (_) {
      return false;
    }
  }

  List<BookComment> _parseComments(String html) {
    final doc = html_parser.parse(html);
    final comments = <BookComment>[];

    // Flibusta book reviews are in <span class="container_{bookId}">
    // Format: <b><a href="/polka/show/ID">username</a></b> в HH:MM (+tz) / DD-MM-YYYY, Оценка: rating<br>review text<div></div><hr>
    final reviewNodes = doc.querySelectorAll('span[class^="container_"]');
    var idx = 0;
    for (final node in reviewNodes) {
      final authorEl = node.querySelector('b a');
      final author = authorEl?.text.trim() ?? '';
      if (author.isEmpty) continue;

      // Get the full text, then split at <br> to separate header from body
      final fullText = node.innerHtml;
      final brIndex = fullText.indexOf('<br');
      if (brIndex < 0) continue;

      final bodyHtml = fullText.substring(brIndex);
      final bodyDoc = html_parser.parse(bodyHtml);
      final body = bodyDoc.body?.text.trim() ?? '';
      // Strip trailing <div></div><hr> artifacts
      final cleanBody = body.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleanBody.isEmpty) continue;

      // Try to extract date from the header text before <br>
      DateTime? createdAt;
      final headerText = fullText.substring(0, brIndex);
      final dateMatch = RegExp(r'/\s*(\d{2})-(\d{2})-(\d{4})').firstMatch(headerText);
      if (dateMatch != null) {
        final day = int.tryParse(dateMatch.group(1) ?? '');
        final month = int.tryParse(dateMatch.group(2) ?? '');
        final year = int.tryParse(dateMatch.group(3) ?? '');
        if (day != null && month != null && year != null) {
          createdAt = DateTime(year, month, day);
        }
      }

      comments.add(
        BookComment(
          id: 'review_${idx++}',
          author: author,
          text: cleanBody,
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
