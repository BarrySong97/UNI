import 'render_node.dart';

class ParsedChapter {
  const ParsedChapter({
    required this.index,
    required this.title,
    required this.href,
    required this.nodes,
  });

  final int index;
  final String title;
  final String href;
  final List<RenderNode> nodes;

  factory ParsedChapter.fromJson(Map<String, dynamic> json) => ParsedChapter(
    index: json['index'] as int,
    title: json['title'] as String? ?? '',
    href: json['href'] as String? ?? '',
    nodes:
        (json['nodes'] as List?)
            ?.map((e) => RenderNode.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

class BookMetadata {
  const BookMetadata({
    required this.title,
    required this.author,
    this.language,
    this.coverImageBase64,
  });

  final String title;
  final String author;
  final String? language;
  final String? coverImageBase64;

  factory BookMetadata.fromJson(Map<String, dynamic> json) => BookMetadata(
    title: json['title'] as String? ?? '',
    author: json['author'] as String? ?? '',
    language: json['language'] as String?,
    coverImageBase64: json['cover_image_base64'] as String?,
  );
}

class TocEntry {
  const TocEntry({
    required this.title,
    required this.href,
    this.children = const [],
  });

  final String title;
  final String href;
  final List<TocEntry> children;

  factory TocEntry.fromJson(Map<String, dynamic> json) => TocEntry(
    title: json['title'] as String? ?? '',
    href: json['href'] as String? ?? '',
    children:
        (json['children'] as List?)
            ?.map((e) => TocEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

class ParsedBook {
  const ParsedBook({
    required this.metadata,
    required this.toc,
    required this.chapters,
  });

  final BookMetadata metadata;
  final List<TocEntry> toc;
  final List<ParsedChapter> chapters;

  factory ParsedBook.fromJson(Map<String, dynamic> json) => ParsedBook(
    metadata: BookMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    toc:
        (json['toc'] as List?)
            ?.map((e) => TocEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    chapters:
        (json['chapters'] as List?)
            ?.map((e) => ParsedChapter.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}
