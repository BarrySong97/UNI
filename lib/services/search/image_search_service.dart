import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Supported image search engines.
enum ImageSearchEngine { google, bing, baidu }

/// A single image search result with thumbnail and source URLs.
class ImageSearchResult {
  const ImageSearchResult({required this.thumbnailUrl, required this.sourceUrl});

  final String thumbnailUrl;
  final String sourceUrl;
}

/// Fetches image search results by scraping search engine web pages.
///
/// No API keys required -- uses direct HTTP GET with browser-like User-Agent
/// and parses the response HTML/JSON with regex (same pattern as
/// `book-import-service.dart`).
class ImageSearchService {
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';

  /// Search for images matching [query] using the given [engine].
  /// Returns up to [count] results.  Never throws -- returns an empty list
  /// on any failure so callers don't need try/catch.
  static Future<List<ImageSearchResult>> search(
    ImageSearchEngine engine,
    String query, {
    int count = 10,
  }) async {
    try {
      switch (engine) {
        case ImageSearchEngine.bing:
          return await _searchBing(query, count);
        case ImageSearchEngine.google:
          return await _searchGoogle(query, count);
        case ImageSearchEngine.baidu:
          return await _searchBaidu(query, count);
      }
    } catch (e) {
      debugPrint('[ImageSearchService] search failed ($engine): $e');
      return const [];
    }
  }

  /// Build the browser URL for "More Images on Internet".
  static String webSearchUrl(ImageSearchEngine engine, String query) {
    final encoded = Uri.encodeComponent(query);
    switch (engine) {
      case ImageSearchEngine.google:
        return 'https://www.google.com/search?q=$encoded&tbm=isch';
      case ImageSearchEngine.bing:
        return 'https://www.bing.com/images/search?q=$encoded';
      case ImageSearchEngine.baidu:
        return 'https://image.baidu.com/search/index?tn=baiduimage&word=$encoded';
    }
  }

  // ---------------------------------------------------------------------------
  // Bing Images
  // ---------------------------------------------------------------------------

  static Future<List<ImageSearchResult>> _searchBing(
    String query,
    int count,
  ) async {
    final encoded = Uri.encodeComponent(query);
    final url = 'https://www.bing.com/images/search?q=$encoded&first=1&count=$count';
    final html = await _fetch(url);
    if (html.isEmpty) return const [];

    // Bing embeds image data in <a class="iusc" m="{JSON}"> tags.
    // The `m` attribute contains JSON with `murl` (media URL) and `turl`
    // (thumbnail URL).  The attribute value is HTML-escaped.
    final pattern = RegExp(r'class="iusc"[^>]*m="([^"]+)"');
    final matches = pattern.allMatches(html);

    final results = <ImageSearchResult>[];
    for (final match in matches) {
      if (results.length >= count) break;
      try {
        final raw = _htmlUnescape(match.group(1)!);
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final turl = json['turl'] as String?;
        final murl = json['murl'] as String?;
        if (turl != null && turl.isNotEmpty) {
          results.add(ImageSearchResult(
            thumbnailUrl: turl,
            sourceUrl: murl ?? turl,
          ));
        }
      } catch (_) {
        // Skip malformed entries.
      }
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // Google Images
  // ---------------------------------------------------------------------------

  static Future<List<ImageSearchResult>> _searchGoogle(
    String query,
    int count,
  ) async {
    final encoded = Uri.encodeComponent(query);
    final url = 'https://www.google.com/search?q=$encoded&tbm=isch&hl=en';
    final html = await _fetch(url);
    if (html.isEmpty) return const [];

    // Google embeds image URLs inside <script> tags.  We extract URLs that
    // look like external image files and skip Google's own assets.
    final urlPattern = RegExp(
      r'https?://[^"' "'" r'\s\]>]+\.(?:jpg|jpeg|png|webp|gif)',
      caseSensitive: false,
    );
    final allUrls = urlPattern.allMatches(html).map((m) => m.group(0)!).toSet();

    // Filter out Google's own domains.
    const googleDomains = [
      'gstatic.com',
      'google.com',
      'googleapis.com',
      'googleusercontent.com',
      'ggpht.com',
    ];

    final results = <ImageSearchResult>[];
    for (final imgUrl in allUrls) {
      if (results.length >= count) break;
      final isGoogleAsset = googleDomains.any((d) => imgUrl.contains(d));
      if (isGoogleAsset) continue;
      results.add(ImageSearchResult(thumbnailUrl: imgUrl, sourceUrl: imgUrl));
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // Baidu Images
  // ---------------------------------------------------------------------------

  static Future<List<ImageSearchResult>> _searchBaidu(
    String query,
    int count,
  ) async {
    final encoded = Uri.encodeComponent(query);
    final url =
        'https://image.baidu.com/search/acjson'
        '?tn=resultjson_com&word=$encoded&pn=0&rn=$count';
    final body = await _fetch(url);
    if (body.isEmpty) return const [];

    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>? ?? [];

      final results = <ImageSearchResult>[];
      for (final item in data) {
        if (results.length >= count) break;
        if (item is! Map<String, dynamic>) continue;
        final thumb = item['thumbURL'] as String? ?? '';
        final middle = item['middleURL'] as String? ?? '';
        if (thumb.isNotEmpty) {
          results.add(ImageSearchResult(
            thumbnailUrl: thumb,
            sourceUrl: middle.isNotEmpty ? middle : thumb,
          ));
        }
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Fetch a URL and return the response body as a UTF-8 string.
  static Future<String> _fetch(String url) async {
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', _userAgent);
      request.headers.set('Accept-Language', 'en-US,en;q=0.9');

      final response = await request.close();
      if (response.statusCode != 200) {
        // Follow one redirect if needed.
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers.value('location');
          if (location != null) {
            final redirectRequest = await client.getUrl(Uri.parse(location));
            redirectRequest.headers.set('User-Agent', _userAgent);
            final redirectResponse = await redirectRequest.close();
            return await redirectResponse.transform(utf8.decoder).join();
          }
        }
        return '';
      }
      return await response.transform(utf8.decoder).join();
    } catch (e) {
      debugPrint('[ImageSearchService] fetch failed: $e');
      return '';
    } finally {
      client.close();
    }
  }

  /// Decode common HTML entities in attribute values.
  static String _htmlUnescape(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }
}
