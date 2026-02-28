import 'dart:convert';
import 'dart:io';

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
  });

  final String title;
  final String author;
  final String sourceType;
  final String sourcePath;
  final List<ImportedChapterDraft> chapters;
  final String format;
}

class BookImportService {
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

    final chapters = _splitTxtChapters(normalized);
    return ImportedBookDraft(
      title: title,
      author: 'Unknown',
      sourceType: 'local_txt',
      sourcePath: file.path,
      chapters: chapters,
      format: format,
    );
  }

  Future<ImportedBookDraft> _importEpub(File file, String format) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);

    final htmlEntries = archive.files
        .where(
          (entry) =>
              !entry.isFile
                  ? false
                  : entry.name.toLowerCase().endsWith('.xhtml') ||
                      entry.name.toLowerCase().endsWith('.html') ||
                      entry.name.toLowerCase().endsWith('.htm'),
        )
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));

    final title = p.basenameWithoutExtension(file.path);
    final chapters = <ImportedChapterDraft>[];

    for (var i = 0; i < htmlEntries.length; i++) {
      final entry = htmlEntries[i];
      final data = entry.content;

      final decoded = utf8.decode(data, allowMalformed: true);
      final cleaned = _stripHtml(decoded).trim();
      if (cleaned.isEmpty) {
        continue;
      }

      chapters.add(
        ImportedChapterDraft(
          title: 'Chapter ${i + 1}',
          content: cleaned,
        ),
      );
    }

    if (chapters.isEmpty) {
      chapters.add(
        const ImportedChapterDraft(
          title: 'Chapter 1',
          content: 'Unable to parse this EPUB content. Please try another file.',
        ),
      );
    }

    return ImportedBookDraft(
      title: title,
      author: 'Unknown',
      sourceType: 'local_epub',
      sourcePath: file.path,
      chapters: chapters,
      format: format,
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
      chapters: <ImportedChapterDraft>[chapter],
      format: format,
    );
  }

  List<ImportedChapterDraft> _splitTxtChapters(String content) {
    if (content.isEmpty) {
      return const <ImportedChapterDraft>[
        ImportedChapterDraft(title: 'Chapter 1', content: 'Empty file.'),
      ];
    }

    final lines = content.split('\n');
    final chapterHeader = RegExp(r'^(chapter\s+\d+|第.{1,9}章)', caseSensitive: false);
    final chapters = <ImportedChapterDraft>[];

    String currentTitle = 'Chapter 1';
    final buffer = StringBuffer();

    for (final line in lines) {
      if (chapterHeader.hasMatch(line.trim()) && buffer.isNotEmpty) {
        chapters.add(ImportedChapterDraft(title: currentTitle, content: buffer.toString().trim()));
        buffer.clear();
        currentTitle = line.trim();
        continue;
      }

      if (chapterHeader.hasMatch(line.trim()) && buffer.isEmpty) {
        currentTitle = line.trim();
        continue;
      }

      buffer.writeln(line);
    }

    if (buffer.isNotEmpty) {
      chapters.add(ImportedChapterDraft(title: currentTitle, content: buffer.toString().trim()));
    }

    if (chapters.isEmpty) {
      chapters.add(ImportedChapterDraft(title: 'Chapter 1', content: content));
    }

    return chapters;
  }

  String _stripHtml(String html) {
    final removedScripts = html
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false), ' ');
    final noTags = removedScripts.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return noTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
