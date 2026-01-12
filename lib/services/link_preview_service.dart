import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';

/// Data model for a fetched link preview
class LinkPreviewData {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  const LinkPreviewData({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });
}

/// Lightweight metadata fetcher for Open Graph/Twitter meta tags.
///
/// Strategy:
/// 1) Try direct GET and parse <meta> tags (mobile works; web may hit CORS).
/// 2) If direct fetch fails on web, fallback to Firebase HTTPS Callable: `fetchMeta`.
///    The callable should return { title, description, image, siteName }.
class LinkPreviewService {
  static final RegExp _metaTag = RegExp(
    r'''<meta[^>]+(?:property|name)=(?:"|')([^"']+)(?:"|')[^>]*content=(?:"|')([^"']*)(?:"|')''',
    caseSensitive: false,
  );

  Future<LinkPreviewData?> fetch(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _parseHtml(url, utf8.decode(res.bodyBytes));
      }
    } catch (e) {
      debugPrint('Direct metadata fetch failed (likely CORS on web): $e');
    }

    // Fallback to Firebase Callable if available
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('fetchMeta');
      final resp = await callable.call(<String, dynamic>{'url': url});
      final data = Map<String, dynamic>.from(resp.data as Map);
      return LinkPreviewData(
        url: url,
        title: data['title'] as String?,
        description: data['description'] as String?,
        imageUrl: data['image'] as String?,
        siteName: data['siteName'] as String?,
      );
    } catch (e) {
      debugPrint('Callable fetchMeta not available or failed: $e');
      return LinkPreviewData(url: url);
    }
  }

  LinkPreviewData _parseHtml(String url, String html) {
    String? title;
    String? description;
    String? image;
    String? site;

    for (final m in _metaTag.allMatches(html)) {
      final key = (m.group(1) ?? '').toLowerCase();
      final value = m.group(2);
      if (value == null || value.isEmpty) continue;
      switch (key) {
        case 'og:title':
        case 'twitter:title':
          title ??= value;
          break;
        case 'og:description':
        case 'twitter:description':
        case 'description':
          description ??= value;
          break;
        case 'og:image':
        case 'twitter:image':
          image ??= value;
          break;
        case 'og:site_name':
          site ??= value;
          break;
      }
    }

    // Also attempt to use <title> as a fallback
    if (title == null) {
      final t = RegExp(r'<title[^>]*>(.*?)<\/title>', caseSensitive: false, dotAll: true)
          .firstMatch(html)
          ?.group(1)
          ?.trim();
      if (t != null && t.isNotEmpty) title = t;
    }

    return LinkPreviewData(url: url, title: title, description: description, imageUrl: image, siteName: site);
  }
}
