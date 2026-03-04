import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class ImportedChapterDraft {
  const ImportedChapterDraft({required this.title, required this.content});

  final String title;
  final String content;
}

class ImportedBookDraft {
  const ImportedBookDraft({
    required this.title,
    required this.author,
    required this.sourceType,
    required this.sourcePath,
    required this.chapters,
    required this.format,
    this.coverUrl,
  });

  final String title;
  final String author;
  final String sourceType;
  final String sourcePath;
  final List<ImportedChapterDraft> chapters;
  final String format;
  final String? coverUrl;
}

class BookImportService {
  static const int _epubChapterMaxChars = 6000;
  static const Set<String> supportedExtensions = <String>{
    'txt',
    'epub',
    'pdf',
    'mobi',
    'azw',
    'azw3',
    'fb2',
  };

  Future<ImportedBookDraft> importFromPath(String path) async {
    final extension = p.extension(path).toLowerCase().replaceFirst('.', '');
    if (!supportedExtensions.contains(extension)) {
      throw UnsupportedError('Unsupported format: $extension');
    }

    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('File does not exist', path);
    }

    switch (extension) {
      case 'txt':
        return _importTxt(file, extension);
      case 'epub':
        return _importEpub(file, extension);
      default:
        return _importPlaceholder(file, extension);
    }
  }

  Future<ImportedBookDraft> _importTxt(File file, String format) async {
    final raw = await file.readAsString();
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    final title = p.basenameWithoutExtension(file.path);

    final chapters = _normalizeChapterTitles(_splitTxtChapters(normalized));
    return ImportedBookDraft(
      title: title,
      author: 'Unknown',
      sourceType: 'local_txt',
      sourcePath: file.path,
      chapters: chapters,
      format: format,
      coverUrl: null,
    );
  }

  Future<ImportedBookDraft> _importEpub(File file, String format) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);

    final opfPath = _findOpfPath(archive);
    final metadata = _extractEpubMetadata(archive, opfPath);
    final coverUrl = _extractEpubCoverDataUrl(archive, opfPath);
    final tocTitleByPath = _extractEpubTocTitleByPath(archive, opfPath);

    final htmlEntries = _resolveEpubHtmlEntries(
      archive: archive,
      opfPath: opfPath,
    );

    final title =
        _sanitizeMetadataText(metadata.title) ??
        p.basenameWithoutExtension(file.path);
    final author = _sanitizeMetadataText(metadata.author) ?? 'Unknown';
    final chapters = <ImportedChapterDraft>[];

    for (var i = 0; i < htmlEntries.length; i++) {
      final entry = htmlEntries[i];
      final data = _readEntryBytes(entry);

      final decoded = utf8.decode(data, allowMalformed: true);
      final cleaned = _extractReadableTextFromHtml(decoded);
      if (cleaned.isEmpty) {
        continue;
      }
      final extractedTitle = _extractChapterTitleFromHtml(decoded);
      final tocTitle =
          tocTitleByPath[_normalizeEpubPath(entry.name)] ??
          tocTitleByPath[_normalizeEpubPath(p.basename(entry.name))];
      final baseTitle = tocTitle ?? extractedTitle ?? 'Chapter ${i + 1}';
      chapters.addAll(
        _splitLongEpubChapter(title: baseTitle, content: cleaned),
      );
    }

    if (chapters.isEmpty) {
      chapters.add(
        const ImportedChapterDraft(
          title: 'Chapter 1',
          content:
              'Unable to parse this EPUB content. Please try another file.',
        ),
      );
    }

    return ImportedBookDraft(
      title: title,
      author: author,
      sourceType: 'local_epub',
      sourcePath: file.path,
      chapters: _normalizeChapterTitles(chapters),
      format: format,
      coverUrl: coverUrl,
    );
  }

  Future<ImportedBookDraft> _importPlaceholder(File file, String format) async {
    final title = p.basenameWithoutExtension(file.path);
    final chapter = ImportedChapterDraft(
      title: 'Import Notice',
      content:
          'This $format file was imported to your library. Reading parser for $format is not implemented yet in MVP.',
    );

    return ImportedBookDraft(
      title: title,
      author: 'Unknown',
      sourceType: 'local_$format',
      sourcePath: file.path,
      chapters: _normalizeChapterTitles(<ImportedChapterDraft>[chapter]),
      format: format,
      coverUrl: null,
    );
  }

  List<ImportedChapterDraft> _splitTxtChapters(String content) {
    if (content.isEmpty) {
      return const <ImportedChapterDraft>[
        ImportedChapterDraft(title: 'Chapter 1', content: 'Empty file.'),
      ];
    }

    final lines = content.split('\n');
    final chapterHeader = RegExp(
      r'^(chapter\s+\d+|第.{1,9}章)',
      caseSensitive: false,
    );
    final chapters = <ImportedChapterDraft>[];
    var hasExplicitHeader = false;

    String currentTitle = 'Chapter 1';
    final buffer = StringBuffer();

    for (final line in lines) {
      if (chapterHeader.hasMatch(line.trim()) && buffer.isNotEmpty) {
        hasExplicitHeader = true;
        chapters.add(
          ImportedChapterDraft(
            title: currentTitle,
            content: buffer.toString().trim(),
          ),
        );
        buffer.clear();
        currentTitle = line.trim();
        continue;
      }

      if (chapterHeader.hasMatch(line.trim()) && buffer.isEmpty) {
        hasExplicitHeader = true;
        currentTitle = line.trim();
        continue;
      }

      buffer.writeln(line);
    }

    if (buffer.isNotEmpty) {
      final fallbackTitle = !hasExplicitHeader && currentTitle == 'Chapter 1'
          ? (_inferChapterTitleFromContent(buffer.toString()) ?? currentTitle)
          : currentTitle;
      chapters.add(
        ImportedChapterDraft(
          title: fallbackTitle,
          content: buffer.toString().trim(),
        ),
      );
    }

    if (chapters.isEmpty) {
      chapters.add(
        ImportedChapterDraft(
          title: _inferChapterTitleFromContent(content) ?? 'Chapter 1',
          content: content,
        ),
      );
    }

    return chapters;
  }

  List<ImportedChapterDraft> _normalizeChapterTitles(
    List<ImportedChapterDraft> chapters,
  ) {
    return List<ImportedChapterDraft>.generate(chapters.length, (index) {
      final chapter = chapters[index];
      final normalized = _sanitizeChapterTitle(chapter.title);
      final fromContent = _inferChapterTitleFromContent(chapter.content);
      final fallback = _defaultChapterTitle(index + 1, chapter.content);
      return ImportedChapterDraft(
        title: normalized ?? fromContent ?? fallback,
        content: chapter.content,
      );
    }, growable: false);
  }

  String? _extractChapterTitleFromHtml(String html) {
    for (final tag in <String>['h1', 'h2', 'h3', 'title']) {
      final match = RegExp(
        '<$tag\\b[^>]*>([\\s\\S]*?)<\\/$tag>',
        caseSensitive: false,
      ).firstMatch(html);
      if (match == null) {
        continue;
      }
      final raw = match.group(1);
      if (raw == null) {
        continue;
      }
      final cleaned = _sanitizeChapterTitle(_stripHtml(raw));
      if (cleaned != null) {
        return cleaned;
      }
    }
    return null;
  }

  String? _inferChapterTitleFromContent(String content) {
    for (final line in content.split('\n')) {
      final candidate = _sanitizeChapterTitle(line);
      if (candidate != null) {
        return candidate;
      }
    }
    return null;
  }

  String? _sanitizeChapterTitle(String? input) {
    if (input == null) {
      return null;
    }
    final cleaned = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) {
      return null;
    }
    return cleaned.length > 80 ? '${cleaned.substring(0, 80)}...' : cleaned;
  }

  String _defaultChapterTitle(int index, String content) {
    final hasCjk = RegExp(r'[\u4e00-\u9fff]').hasMatch(content);
    if (hasCjk) {
      return '第$index章';
    }
    return 'Chapter $index';
  }

  String _stripHtml(String html) {
    final removedScripts = html
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false),
          ' ',
        );
    final noTags = removedScripts.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return noTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _extractReadableTextFromHtml(String html) {
    var source = html
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(
            r'<\/(p|div|h1|h2|h3|h4|h5|h6|li|blockquote|section|article)>',
            caseSensitive: false,
          ),
          '\n\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    source = _decodeHtmlEntities(source);

    final lines = source
        .split(RegExp(r'\n+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return lines.join('\n\n').trim();
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  List<ImportedChapterDraft> _splitLongEpubChapter({
    required String title,
    required String content,
  }) {
    if (content.length <= _epubChapterMaxChars) {
      return <ImportedChapterDraft>[
        ImportedChapterDraft(title: title, content: content),
      ];
    }
    final blocks = content
        .split(RegExp(r'\n{2,}'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (blocks.isEmpty) {
      return <ImportedChapterDraft>[
        ImportedChapterDraft(title: title, content: content),
      ];
    }

    final chunks = <String>[];
    final buffer = StringBuffer();
    for (final block in blocks) {
      final nextLen = buffer.length + block.length + 2;
      if (buffer.isNotEmpty && nextLen > _epubChapterMaxChars) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
      if (buffer.isNotEmpty) {
        buffer.writeln();
        buffer.writeln();
      }
      buffer.write(block);
    }
    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString().trim());
    }

    return List<ImportedChapterDraft>.generate(chunks.length, (index) {
      final partTitle = index == 0 ? title : '$title (${index + 1})';
      return ImportedChapterDraft(title: partTitle, content: chunks[index]);
    }, growable: false);
  }

  String? _findOpfPath(Archive archive) {
    const containerPath = 'META-INF/container.xml';
    final container = _findArchiveFile(archive, containerPath);
    if (container != null) {
      final xml = utf8.decode(_readEntryBytes(container), allowMalformed: true);
      final match = RegExp(
        "full-path\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]",
        caseSensitive: false,
      ).firstMatch(xml);
      if (match != null) {
        return match.group(1);
      }
    }

    final fallback = archive.files.firstWhere(
      (entry) => entry.isFile && entry.name.toLowerCase().endsWith('.opf'),
      orElse: () => ArchiveFile('', 0, Uint8List(0)),
    );
    return fallback.name.isEmpty ? null : fallback.name;
  }

  List<ArchiveFile> _resolveEpubHtmlEntries({
    required Archive archive,
    required String? opfPath,
  }) {
    final fallback =
        archive.files
            .where(
              (entry) => !entry.isFile
                  ? false
                  : entry.name.toLowerCase().endsWith('.xhtml') ||
                        entry.name.toLowerCase().endsWith('.html') ||
                        entry.name.toLowerCase().endsWith('.htm'),
            )
            .toList(growable: false)
          ..sort((a, b) => a.name.compareTo(b.name));
    if (opfPath == null) {
      return fallback;
    }

    final opfEntry = _findArchiveFile(archive, opfPath);
    if (opfEntry == null) {
      return fallback;
    }
    final opf = utf8.decode(_readEntryBytes(opfEntry), allowMalformed: true);

    final manifestHrefById = <String, String>{};
    final itemTags = RegExp(
      r'<item\b[^>]*>',
      caseSensitive: false,
    ).allMatches(opf);
    for (final match in itemTags) {
      final tag = match.group(0)!;
      final id = _attribute(tag, 'id');
      final href = _attribute(tag, 'href');
      if (id == null || href == null) {
        continue;
      }
      final mediaType = _attribute(tag, 'media-type')?.toLowerCase() ?? '';
      final lowerHref = href.toLowerCase();
      final isHtml =
          mediaType.contains('xhtml') ||
          mediaType.contains('html') ||
          lowerHref.endsWith('.xhtml') ||
          lowerHref.endsWith('.html') ||
          lowerHref.endsWith('.htm');
      if (!isHtml) {
        continue;
      }
      manifestHrefById[id] = href;
    }

    final baseDir = p.dirname(opfPath);
    final ordered = <ArchiveFile>[];
    final seen = <String>{};
    final itemRefs = RegExp(
      r'<itemref\b[^>]*>',
      caseSensitive: false,
    ).allMatches(opf);
    for (final match in itemRefs) {
      final tag = match.group(0)!;
      final idref = _attribute(tag, 'idref');
      if (idref == null) {
        continue;
      }
      final href = manifestHrefById[idref];
      if (href == null) {
        continue;
      }
      final resolvedPath = p
          .normalize(p.join(baseDir, href))
          .replaceAll('\\', '/');
      final entry = _findArchiveFile(archive, resolvedPath);
      if (entry == null) {
        continue;
      }
      final key = entry.name.toLowerCase();
      if (seen.add(key)) {
        ordered.add(entry);
      }
    }
    return ordered.isEmpty ? fallback : ordered;
  }

  Map<String, String> _extractEpubTocTitleByPath(
    Archive archive,
    String? opfPath,
  ) {
    if (opfPath == null) {
      return const <String, String>{};
    }
    final opfEntry = _findArchiveFile(archive, opfPath);
    if (opfEntry == null) {
      return const <String, String>{};
    }
    final opf = utf8.decode(_readEntryBytes(opfEntry), allowMalformed: true);
    final manifestById = <String, String>{};
    final navIds = <String>{};
    final ncxIds = <String>{};
    final itemTags = RegExp(
      r'<item\b[^>]*>',
      caseSensitive: false,
    ).allMatches(opf);
    for (final match in itemTags) {
      final tag = match.group(0)!;
      final id = _attribute(tag, 'id');
      final href = _attribute(tag, 'href');
      if (id == null || href == null) {
        continue;
      }
      manifestById[id] = href;
      final properties = (_attribute(tag, 'properties') ?? '').toLowerCase();
      final mediaType = (_attribute(tag, 'media-type') ?? '').toLowerCase();
      if (properties.contains('nav')) {
        navIds.add(id);
      }
      if (mediaType.contains('ncx')) {
        ncxIds.add(id);
      }
    }
    final baseDir = p.dirname(opfPath);

    for (final navId in navIds) {
      final href = manifestById[navId];
      if (href == null) {
        continue;
      }
      final resolved = _resolveHref(baseDir: baseDir, href: href);
      final entry = _findArchiveFile(archive, resolved);
      if (entry == null) {
        continue;
      }
      final xml = utf8.decode(_readEntryBytes(entry), allowMalformed: true);
      final mapped = _parseNavXhtmlToc(
        content: xml,
        hrefBaseDir: p.dirname(resolved),
      );
      if (mapped.isNotEmpty) {
        return mapped;
      }
    }

    for (final ncxId in ncxIds) {
      final href = manifestById[ncxId];
      if (href == null) {
        continue;
      }
      final resolved = _resolveHref(baseDir: baseDir, href: href);
      final entry = _findArchiveFile(archive, resolved);
      if (entry == null) {
        continue;
      }
      final xml = utf8.decode(_readEntryBytes(entry), allowMalformed: true);
      final mapped = _parseNcxToc(
        content: xml,
        hrefBaseDir: p.dirname(resolved),
      );
      if (mapped.isNotEmpty) {
        return mapped;
      }
    }
    return const <String, String>{};
  }

  Map<String, String> _parseNavXhtmlToc({
    required String content,
    required String hrefBaseDir,
  }) {
    final mapped = <String, String>{};
    final linkMatches = RegExp(
      '<a\\b[^>]*href\\s*=\\s*[\'"]([^\'"]+)[\'"][^>]*>([\\s\\S]*?)<\\/a>',
      caseSensitive: false,
    ).allMatches(content);
    for (final match in linkMatches) {
      final href = match.group(1);
      final label = match.group(2);
      if (href == null || label == null) {
        continue;
      }
      final normalizedHref = _normalizeHrefNoFragment(href);
      if (normalizedHref.isEmpty) {
        continue;
      }
      final resolvedPath = _resolveHref(
        baseDir: hrefBaseDir,
        href: normalizedHref,
      );
      final title = _sanitizeChapterTitle(_stripHtml(label));
      if (title == null) {
        continue;
      }
      mapped.putIfAbsent(_normalizeEpubPath(resolvedPath), () => title);
      mapped.putIfAbsent(
        _normalizeEpubPath(p.basename(resolvedPath)),
        () => title,
      );
    }
    return mapped;
  }

  Map<String, String> _parseNcxToc({
    required String content,
    required String hrefBaseDir,
  }) {
    final mapped = <String, String>{};
    final navPoints = RegExp(
      r'<navPoint\b[\s\S]*?<\/navPoint>',
      caseSensitive: false,
    ).allMatches(content);
    for (final match in navPoints) {
      final raw = match.group(0);
      if (raw == null) {
        continue;
      }
      final src = RegExp(
        '<content\\b[^>]*src\\s*=\\s*[\'"]([^\'"]+)[\'"][^>]*\\/?>',
        caseSensitive: false,
      ).firstMatch(raw)?.group(1);
      final text = RegExp(
        r'<text\b[^>]*>([\s\S]*?)<\/text>',
        caseSensitive: false,
      ).firstMatch(raw)?.group(1);
      if (src == null || text == null) {
        continue;
      }
      final normalizedHref = _normalizeHrefNoFragment(src);
      if (normalizedHref.isEmpty) {
        continue;
      }
      final resolvedPath = _resolveHref(
        baseDir: hrefBaseDir,
        href: normalizedHref,
      );
      final title = _sanitizeChapterTitle(_stripHtml(text));
      if (title == null) {
        continue;
      }
      mapped.putIfAbsent(_normalizeEpubPath(resolvedPath), () => title);
      mapped.putIfAbsent(
        _normalizeEpubPath(p.basename(resolvedPath)),
        () => title,
      );
    }
    return mapped;
  }

  String _resolveHref({required String baseDir, required String href}) {
    return p.normalize(p.join(baseDir, href)).replaceAll('\\', '/');
  }

  String _normalizeHrefNoFragment(String href) {
    final idx = href.indexOf('#');
    return (idx >= 0 ? href.substring(0, idx) : href).trim();
  }

  String _normalizeEpubPath(String path) {
    return path.replaceAll('\\', '/').toLowerCase();
  }

  String? _extractEpubCoverDataUrl(Archive archive, String? opfPath) {
    if (opfPath == null) {
      return null;
    }
    final opfEntry = _findArchiveFile(archive, opfPath);
    if (opfEntry == null) {
      return null;
    }
    final opf = utf8.decode(_readEntryBytes(opfEntry), allowMalformed: true);

    final manifestById =
        <String, ({String href, String? mediaType, String? properties})>{};
    final itemTags = RegExp(
      r'<item\b[^>]*>',
      caseSensitive: false,
    ).allMatches(opf);
    for (final match in itemTags) {
      final tag = match.group(0)!;
      final id = _attribute(tag, 'id');
      final href = _attribute(tag, 'href');
      if (id == null || href == null) {
        continue;
      }
      manifestById[id] = (
        href: href,
        mediaType: _attribute(tag, 'media-type'),
        properties: _attribute(tag, 'properties'),
      );
    }

    String? coverId;
    final metaCover = RegExp(
      "<meta\\b[^>]*name\\s*=\\s*['\\\"]cover['\\\"][^>]*>",
      caseSensitive: false,
    ).firstMatch(opf);
    if (metaCover != null) {
      coverId = _attribute(metaCover.group(0)!, 'content');
    }

    String? coverHref;
    String? mediaType;
    if (coverId != null && manifestById.containsKey(coverId)) {
      final item = manifestById[coverId]!;
      coverHref = item.href;
      mediaType = item.mediaType;
    }

    if (coverHref == null) {
      for (final item in manifestById.values) {
        final properties = item.properties?.toLowerCase() ?? '';
        if (properties.contains('cover-image')) {
          coverHref = item.href;
          mediaType = item.mediaType;
          break;
        }
      }
    }

    if (coverHref == null) {
      for (final item in manifestById.values) {
        final href = item.href.toLowerCase();
        final type = item.mediaType?.toLowerCase() ?? '';
        if (href.contains('cover') && type.startsWith('image/')) {
          coverHref = item.href;
          mediaType = item.mediaType;
          break;
        }
      }
    }

    if (coverHref == null) {
      return null;
    }

    final baseDir = p.dirname(opfPath);
    final resolvedPath = p
        .normalize(p.join(baseDir, coverHref))
        .replaceAll('\\', '/');
    final coverEntry = _findArchiveFile(archive, resolvedPath);
    if (coverEntry == null) {
      return null;
    }

    final mime = mediaType ?? _guessImageMime(resolvedPath);
    if (mime == null) {
      return null;
    }
    final bytes = _readEntryBytes(coverEntry);
    if (bytes.isEmpty) {
      return null;
    }
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  ({String? title, String? author}) _extractEpubMetadata(
    Archive archive,
    String? opfPath,
  ) {
    if (opfPath == null) {
      return (title: null, author: null);
    }
    final opfEntry = _findArchiveFile(archive, opfPath);
    if (opfEntry == null) {
      return (title: null, author: null);
    }

    final opf = utf8.decode(_readEntryBytes(opfEntry), allowMalformed: true);
    final title = _extractXmlText(opf, <String>['dc:title', 'title']);
    final author = _extractXmlText(opf, <String>['dc:creator', 'creator']);
    return (title: title, author: author);
  }

  ArchiveFile? _findArchiveFile(Archive archive, String path) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    for (final entry in archive.files) {
      if (entry.isFile &&
          entry.name.replaceAll('\\', '/').toLowerCase() == normalized) {
        return entry;
      }
    }
    return null;
  }

  Uint8List _readEntryBytes(ArchiveFile entry) {
    return Uint8List.fromList(entry.content);
  }

  String? _attribute(String tag, String attribute) {
    final match = RegExp(
      "$attribute\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]",
      caseSensitive: false,
    ).firstMatch(tag);
    return match?.group(1);
  }

  String? _guessImageMime(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  String? _extractXmlText(String source, List<String> tags) {
    for (final tag in tags) {
      final match = RegExp(
        '<$tag\\b[^>]*>([\\s\\S]*?)<\\/$tag>',
        caseSensitive: false,
      ).firstMatch(source);
      if (match == null) {
        continue;
      }
      final raw = match.group(1);
      if (raw == null) {
        continue;
      }
      final cleaned = _stripHtml(raw).trim();
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }
    return null;
  }

  String? _sanitizeMetadataText(String? input) {
    if (input == null) {
      return null;
    }
    final cleaned = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) {
      return null;
    }
    return cleaned;
  }
}
