import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class ImportedBookDraft {
  const ImportedBookDraft({
    required this.title,
    required this.author,
    required this.sourceType,
    required this.sourcePath,
    required this.format,
    this.coverUrl,
    this.language,
  });

  final String title;
  final String author;
  final String sourceType;
  final String sourcePath;
  final String format;
  final String? coverUrl;
  final String? language;
}

class BookImportService {
  static const Set<String> supportedExtensions = <String>{'epub'};

  Future<ImportedBookDraft> importFromPath(String path) async {
    final extension = p.extension(path).toLowerCase().replaceFirst('.', '');
    if (!supportedExtensions.contains(extension)) {
      throw UnsupportedError(
        'Unsupported format: $extension. Only EPUB is supported.',
      );
    }

    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('File does not exist', path);
    }

    return _importEpub(file);
  }

  Future<ImportedBookDraft> _importEpub(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);

    final opfPath = _findOpfPath(archive);
    final metadata = _extractEpubMetadata(archive, opfPath);
    final coverUrl = _extractEpubCoverDataUrl(archive, opfPath);

    final title =
        _sanitizeMetadataText(metadata.title) ??
        p.basenameWithoutExtension(file.path);
    final author = _sanitizeMetadataText(metadata.author) ?? 'Unknown';

    final language = _sanitizeMetadataText(metadata.language);

    return ImportedBookDraft(
      title: title,
      author: author,
      sourceType: 'local_epub',
      sourcePath: file.path,
      format: 'epub',
      coverUrl: coverUrl,
      language: language,
    );
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

  ({String? title, String? author, String? language}) _extractEpubMetadata(
    Archive archive,
    String? opfPath,
  ) {
    if (opfPath == null) {
      return (title: null, author: null, language: null);
    }
    final opfEntry = _findArchiveFile(archive, opfPath);
    if (opfEntry == null) {
      return (title: null, author: null, language: null);
    }

    final opf = utf8.decode(_readEntryBytes(opfEntry), allowMalformed: true);
    final title = _extractXmlText(opf, <String>['dc:title', 'title']);
    final author = _extractXmlText(opf, <String>['dc:creator', 'creator']);
    final language = _extractXmlText(opf, <String>['dc:language', 'language']);
    return (title: title, author: author, language: language);
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
