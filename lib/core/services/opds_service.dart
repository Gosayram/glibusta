import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xml/xml.dart';

class OpdsCatalog {
  const OpdsCatalog({
    required this.id,
    required this.name,
    required this.url,
    this.username,
    this.password,
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final String url;
  final String? username;
  final String? password;
  final bool isBuiltIn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'username': username,
    'password': password,
    'isBuiltIn': isBuiltIn,
  };

  factory OpdsCatalog.fromJson(Map<String, dynamic> json) => OpdsCatalog(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    username: json['username'] as String?,
    password: json['password'] as String?,
    isBuiltIn: json['isBuiltIn'] as bool? ?? false,
  );
}

class OpdsEntry {
  const OpdsEntry({
    required this.title,
    required this.id,
    this.author,
    this.summary,
    this.coverUrl,
    this.downloadUrl,
    this.contentType,
    this.links = const [],
  });

  final String title;
  final String id;
  final String? author;
  final String? summary;
  final String? coverUrl;
  final String? downloadUrl;
  final String? contentType;
  final List<OpdsLink> links;
}

class OpdsLink {
  const OpdsLink({
    required this.href,
    required this.rel,
    this.type,
    this.title,
  });

  final String href;
  final String rel;
  final String? type;
  final String? title;
}

class OpdsService {
  OpdsService(this._dio);

  final Dio _dio;

  Future<List<OpdsEntry>> fetchFeed(String url, {String? username, String? password}) async {
    final response = await _dio.get<dynamic>(
      url,
      options: username != null
          ? Options(
              headers: {
                'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}',
              },
            )
          : null,
    );

    final xmlStr = response.data.toString();
    final doc = XmlDocument.parse(xmlStr);
    final entries = <OpdsEntry>[];

    for (final entry in doc.findAllElements('entry')) {
      final title = entry.findElements('title').firstOrNull?.innerText ?? '';
      final id = entry.findElements('id').firstOrNull?.innerText ?? '';
      final author = entry
          .findElements('author')
          .firstOrNull
          ?.findElements('name')
          .firstOrNull
          ?.innerText;
      final summary = entry.findElements('summary').firstOrNull?.innerText;
      final content = entry.findElements('content').firstOrNull?.innerText;

      String? coverUrl;
      String? downloadUrl;
      String? contentType;
      final links = <OpdsLink>[];

      for (final link in entry.findAllElements('link')) {
        final href = link.getAttribute('href') ?? '';
        final rel = link.getAttribute('rel') ?? '';
        final type = link.getAttribute('type');
        final title = link.getAttribute('title');

        links.add(OpdsLink(href: href, rel: rel, type: type, title: title));

        if (rel == 'http://opds-spec.org/image/thumbnail' || rel == 'http://opds-spec.org/cover') {
          coverUrl = href;
        }
        if (rel == 'http://opds-spec.org/open-access' || rel.contains('download')) {
          downloadUrl = href;
          contentType = type;
        }
      }

      entries.add(
        OpdsEntry(
          title: title,
          id: id,
          author: author,
          summary: summary ?? content,
          coverUrl: coverUrl,
          downloadUrl: downloadUrl,
          contentType: contentType,
          links: links,
        ),
      );
    }

    return entries;
  }

  Future<List<OpdsEntry>> search(
    String catalogUrl,
    String query, {
    String? username,
    String? password,
  }) async {
    final searchUrl = '$catalogUrl?search=${Uri.encodeComponent(query)}';
    return fetchFeed(searchUrl, username: username, password: password);
  }
}

const builtInCatalogs = [
  OpdsCatalog(
    id: 'flibusta_main',
    name: 'Flibusta (Main)',
    url: 'https://flibusta.is/opds',
    isBuiltIn: true,
  ),
  OpdsCatalog(
    id: 'flibusta_recent',
    name: 'Flibusta (Recent)',
    url: 'https://flibusta.is/opds/recent',
    isBuiltIn: true,
  ),
];

final opdsServiceProvider = Provider<OpdsService>((ref) {
  return OpdsService(
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
      ),
    ),
  );
});
