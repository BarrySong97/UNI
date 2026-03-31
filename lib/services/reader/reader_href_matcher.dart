import 'models/parsed_chapter.dart';

/// Spine href matcher used by reader TOC/title mapping.
///
/// Matching priority:
/// 1) full normalized path (without fragment/query)
/// 2) normalized suffix path (excluding full path and filename-only)
/// 3) filename fallback
///
/// Fallback keys are only used when unique across spine chapters.
class ReaderHrefIndex {
  ReaderHrefIndex._(this._full, this._fallback);

  final Map<String, int> _full;
  final Map<String, int> _fallback;

  factory ReaderHrefIndex.fromChapters(List<ParsedChapter> chapters) {
    final full = <String, int>{};
    final fallback = <String, int>{};
    final ambiguousFallback = <String>{};

    for (final chapter in chapters) {
      final keys = orderedMatchKeys(chapter.href);
      if (keys.isEmpty) continue;

      full.putIfAbsent(keys.first, () => chapter.index);
      for (final key in keys.skip(1)) {
        if (ambiguousFallback.contains(key)) continue;
        final existing = fallback[key];
        if (existing == null) {
          fallback[key] = chapter.index;
          continue;
        }
        if (existing != chapter.index) {
          fallback.remove(key);
          ambiguousFallback.add(key);
        }
      }
    }

    return ReaderHrefIndex._(full, fallback);
  }

  int? resolve(String href) {
    final keys = orderedMatchKeys(href);
    if (keys.isEmpty) return null;

    final fullHit = _full[keys.first];
    if (fullHit != null) return fullHit;

    for (final key in keys.skip(1)) {
      final hit = _fallback[key];
      if (hit != null) return hit;
    }
    return null;
  }

  static List<String> orderedMatchKeys(String href) {
    final segments = _normalizeSegments(href);
    if (segments.isEmpty) return const [];

    final fullPath = segments.join('/');
    final keys = <String>[fullPath];

    // Suffix fallback: e.g. OEBPS/xhtml/content.xhtml -> xhtml/content.xhtml
    if (segments.length >= 3) {
      for (var start = 1; start <= segments.length - 2; start++) {
        keys.add(segments.sublist(start).join('/'));
      }
    }

    // Filename fallback.
    keys.add('file:${segments.last}');
    return keys;
  }

  static List<int> collectTocChapterIndexes({
    required List<TocEntry> toc,
    required ReaderHrefIndex hrefIndex,
  }) {
    final result = <int>{};
    void walk(List<TocEntry> entries) {
      for (final entry in entries) {
        final index = hrefIndex.resolve(entry.href);
        if (index != null) result.add(index);
        if (entry.children.isNotEmpty) walk(entry.children);
      }
    }

    walk(toc);
    final ordered = result.toList()..sort();
    return ordered;
  }

  static Map<int, String> collectTocTitlesByChapterIndex({
    required List<TocEntry> toc,
    required ReaderHrefIndex hrefIndex,
  }) {
    final titles = <int, String>{};
    void walk(List<TocEntry> entries) {
      for (final entry in entries) {
        final index = hrefIndex.resolve(entry.href);
        if (index != null && entry.title.isNotEmpty) {
          titles.putIfAbsent(index, () => entry.title);
        }
        if (entry.children.isNotEmpty) walk(entry.children);
      }
    }

    walk(toc);
    return titles;
  }

  static List<String> _normalizeSegments(String href) {
    if (href.isEmpty) return const [];

    var base = href;
    final hash = base.indexOf('#');
    if (hash >= 0) base = base.substring(0, hash);
    final query = base.indexOf('?');
    if (query >= 0) base = base.substring(0, query);

    base = base.replaceAll('\\', '/');
    base = base.replaceAll(RegExp('/+'), '/');

    final rawParts = base.split('/');
    final normalized = <String>[];
    for (final raw in rawParts) {
      if (raw.isEmpty || raw == '.') continue;
      if (raw == '..') {
        if (normalized.isNotEmpty) normalized.removeLast();
        continue;
      }
      normalized.add(raw);
    }
    return normalized;
  }
}
