import 'dart:ui' show TextAlign;

/// Mirrors the Rust `RenderNode` enum from `rust/epub_parser/src/model.rs`.
/// JSON deserialized from Rust CLI output uses `{"type": "Text", ...}` tagged union.
sealed class RenderNode {
  const RenderNode();

  factory RenderNode.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'Text' => TextNode.fromJson(json),
      'Image' => ImageNode.fromJson(json),
      'Paragraph' => ParagraphNode.fromJson(json),
      'Heading' => HeadingNode.fromJson(json),
      'List' => ListNode.fromJson(json),
      'Table' => TableNode.fromJson(json),
      'BlockQuote' => BlockQuoteNode.fromJson(json),
      'CodeBlock' => CodeBlockNode.fromJson(json),
      'LineBreak' => const LineBreakNode(),
      'HorizontalRule' => const HorizontalRuleNode(),
      _ => const LineBreakNode(),
    };
  }
}

class TextNode extends RenderNode {
  const TextNode({
    required this.content,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.lineThrough = false,
    this.fontSizeEm = 1.0,
    this.color,
    this.nodeIndex = 0,
    this.href,
    this.superscript = false,
    this.subscript = false,
    this.backgroundColor,
  });

  final String content;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool lineThrough;
  final double fontSizeEm;
  final int? color; // ARGB u32
  final int nodeIndex;
  final String? href;
  final bool superscript;
  final bool subscript;
  final int? backgroundColor; // ARGB u32 (inline highlight, e.g. <mark>)

  factory TextNode.fromJson(Map<String, dynamic> json) => TextNode(
    content: json['content'] as String,
    bold: json['bold'] as bool? ?? false,
    italic: json['italic'] as bool? ?? false,
    underline: json['underline'] as bool? ?? false,
    lineThrough: json['line_through'] as bool? ?? false,
    fontSizeEm: (json['font_size_em'] as num?)?.toDouble() ?? 1.0,
    color: json['color'] as int?,
    nodeIndex: json['node_index'] as int? ?? 0,
    href: json['href'] as String?,
    superscript: json['superscript'] as bool? ?? false,
    subscript: json['subscript'] as bool? ?? false,
    backgroundColor: json['background_color'] as int?,
  );
}

class ImageNode extends RenderNode {
  const ImageNode({
    this.dataBase64,
    this.alt,
    this.widthHint,
    this.widthPx,
    this.heightPx,
  });

  final String? dataBase64;
  final String? alt;
  final double? widthHint; // 0.0-1.0 relative to container
  final int? widthPx; // Native image width from Rust parser
  final int? heightPx; // Native image height from Rust parser

  factory ImageNode.fromJson(Map<String, dynamic> json) => ImageNode(
    dataBase64: json['data_base64'] as String?,
    alt: json['alt'] as String?,
    widthHint: (json['width_hint'] as num?)?.toDouble(),
    widthPx: json['width_px'] as int?,
    heightPx: json['height_px'] as int?,
  );
}

class ParagraphNode extends RenderNode {
  const ParagraphNode({
    required this.children,
    this.marginTopEm = 0.0,
    this.marginBottomEm = 0.5,
    this.marginLeftEm = 0.0,
    this.marginRightEm = 0.0,
    this.align = TextAlign.left,
    this.textIndentEm,
    this.lineHeightEm,
    this.paddingEm,
    this.backgroundColor,
    this.color,
  });

  final List<RenderNode> children;
  final double marginTopEm;
  final double marginBottomEm;
  final double marginLeftEm;
  final double marginRightEm;
  final TextAlign align;
  final double? textIndentEm;
  final double? lineHeightEm;
  final double? paddingEm;
  final int? backgroundColor; // ARGB u32
  final int? color; // ARGB u32

  factory ParagraphNode.fromJson(Map<String, dynamic> json) => ParagraphNode(
    children: _parseChildren(json['children']),
    marginTopEm: (json['margin_top_em'] as num?)?.toDouble() ?? 0.0,
    marginBottomEm: (json['margin_bottom_em'] as num?)?.toDouble() ?? 0.5,
    marginLeftEm: (json['margin_left_em'] as num?)?.toDouble() ?? 0.0,
    marginRightEm: (json['margin_right_em'] as num?)?.toDouble() ?? 0.0,
    align: _parseTextAlign(json['align'] as String?),
    textIndentEm: (json['text_indent_em'] as num?)?.toDouble(),
    lineHeightEm: (json['line_height_em'] as num?)?.toDouble(),
    paddingEm: (json['padding_em'] as num?)?.toDouble(),
    backgroundColor: json['background_color'] as int?,
    color: json['color'] as int?,
  );
}

class HeadingNode extends RenderNode {
  const HeadingNode({
    required this.level,
    required this.children,
    this.marginTopEm = 0.0,
    this.marginBottomEm = 0.0,
    this.marginLeftEm = 0.0,
    this.marginRightEm = 0.0,
    this.align = TextAlign.left,
    this.color,
    this.textIndentEm,
    this.lineHeightEm,
    this.paddingEm,
    this.backgroundColor,
  });

  final int level; // 1-6
  final List<RenderNode> children;
  final double marginTopEm;
  final double marginBottomEm;
  final double marginLeftEm;
  final double marginRightEm;
  final TextAlign align;
  final int? color; // ARGB u32
  final double? textIndentEm;
  final double? lineHeightEm;
  final double? paddingEm;
  final int? backgroundColor;

  factory HeadingNode.fromJson(Map<String, dynamic> json) => HeadingNode(
    level: json['level'] as int? ?? 1,
    children: _parseChildren(json['children']),
    marginTopEm: (json['margin_top_em'] as num?)?.toDouble() ?? 0.0,
    marginBottomEm: (json['margin_bottom_em'] as num?)?.toDouble() ?? 0.0,
    marginLeftEm: (json['margin_left_em'] as num?)?.toDouble() ?? 0.0,
    marginRightEm: (json['margin_right_em'] as num?)?.toDouble() ?? 0.0,
    align: _parseTextAlign(json['align'] as String?),
    color: json['color'] as int?,
    textIndentEm: (json['text_indent_em'] as num?)?.toDouble(),
    lineHeightEm: (json['line_height_em'] as num?)?.toDouble(),
    paddingEm: (json['padding_em'] as num?)?.toDouble(),
    backgroundColor: json['background_color'] as int?,
  );
}

class ListNode extends RenderNode {
  const ListNode({required this.ordered, required this.items, this.listStyle});

  final bool ordered;
  final List<ListItemNode> items;
  final String? listStyle;

  factory ListNode.fromJson(Map<String, dynamic> json) => ListNode(
    ordered: json['ordered'] as bool? ?? false,
    items:
        (json['items'] as List?)
            ?.map((e) => ListItemNode.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    listStyle: json['list_style'] as String?,
  );
}

class ListItemNode {
  const ListItemNode({
    required this.children,
    this.subNodes = const [],
  });

  final List<RenderNode> children;
  /// Block-level nodes found inside this list item (e.g. nested lists).
  final List<RenderNode> subNodes;

  factory ListItemNode.fromJson(Map<String, dynamic> json) => ListItemNode(
    children: _parseChildren(json['children']),
    subNodes: _parseChildren(json['sub_nodes']),
  );
}

class TableNode extends RenderNode {
  const TableNode({required this.rows, this.caption});

  final List<TableRowNode> rows;
  final List<RenderNode>? caption;

  factory TableNode.fromJson(Map<String, dynamic> json) => TableNode(
    rows:
        (json['rows'] as List?)
            ?.map((e) => TableRowNode.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    caption:
        json['caption'] != null ? _parseChildren(json['caption']) : null,
  );
}

class TableRowNode {
  const TableRowNode({required this.cells, this.isHeader = false});

  final List<TableCellNode> cells;
  final bool isHeader;

  factory TableRowNode.fromJson(Map<String, dynamic> json) => TableRowNode(
    cells:
        (json['cells'] as List?)
            ?.map((e) => TableCellNode.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    isHeader: json['is_header'] as bool? ?? false,
  );
}

class TableCellNode {
  const TableCellNode({
    required this.children,
    this.backgroundColor,
    this.paddingEm,
    this.border,
    this.verticalAlign,
    this.colspan,
    this.rowspan,
  });

  final List<RenderNode> children;
  final int? backgroundColor;
  final double? paddingEm;
  final BorderNode? border;
  final String? verticalAlign;
  final int? colspan;
  final int? rowspan;

  factory TableCellNode.fromJson(Map<String, dynamic> json) => TableCellNode(
    children: _parseChildren(json['children']),
    backgroundColor: json['background_color'] as int?,
    paddingEm: (json['padding_em'] as num?)?.toDouble(),
    border: json['border'] != null
        ? BorderNode.fromJson(json['border'] as Map<String, dynamic>)
        : null,
    verticalAlign: json['vertical_align'] as String?,
    colspan: json['colspan'] as int?,
    rowspan: json['rowspan'] as int?,
  );
}

class BorderNode {
  const BorderNode({this.widthPx = 1.0, this.color, this.style = 'Solid'});

  final double widthPx;
  final int? color;
  final String style; // None, Solid, Dashed, Dotted

  factory BorderNode.fromJson(Map<String, dynamic> json) => BorderNode(
    widthPx: (json['width_px'] as num?)?.toDouble() ?? 1.0,
    color: json['color'] as int?,
    style: json['style'] as String? ?? 'Solid',
  );
}

class BlockQuoteNode extends RenderNode {
  const BlockQuoteNode({
    required this.children,
    this.backgroundColor,
    this.marginTopEm = 0.5,
    this.marginBottomEm = 0.5,
    this.marginLeftEm = 2.0,
    this.marginRightEm = 1.0,
  });

  final List<RenderNode> children;
  final int? backgroundColor;
  final double marginTopEm;
  final double marginBottomEm;
  final double marginLeftEm;
  final double marginRightEm;

  factory BlockQuoteNode.fromJson(Map<String, dynamic> json) => BlockQuoteNode(
    children: _parseChildren(json['children']),
    backgroundColor: json['background_color'] as int?,
    marginTopEm: (json['margin_top_em'] as num?)?.toDouble() ?? 0.5,
    marginBottomEm: (json['margin_bottom_em'] as num?)?.toDouble() ?? 0.5,
    marginLeftEm: (json['margin_left_em'] as num?)?.toDouble() ?? 2.0,
    marginRightEm: (json['margin_right_em'] as num?)?.toDouble() ?? 1.0,
  );
}

class CodeBlockNode extends RenderNode {
  const CodeBlockNode({
    this.content = '',
    this.children = const [],
    this.backgroundColor,
    this.paddingEm,
  });

  /// Legacy plain text content (for backward compatibility with old cache).
  final String content;
  /// Styled inline children (preferred over content when non-empty).
  final List<RenderNode> children;
  final int? backgroundColor;
  final double? paddingEm;

  factory CodeBlockNode.fromJson(Map<String, dynamic> json) => CodeBlockNode(
    content: json['content'] as String? ?? '',
    children: _parseChildren(json['children']),
    backgroundColor: json['background_color'] as int?,
    paddingEm: (json['padding_em'] as num?)?.toDouble(),
  );
}

class LineBreakNode extends RenderNode {
  const LineBreakNode();
}

class HorizontalRuleNode extends RenderNode {
  const HorizontalRuleNode();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<RenderNode> _parseChildren(dynamic childrenJson) {
  if (childrenJson is! List) return const [];
  return childrenJson
      .map((e) => RenderNode.fromJson(e as Map<String, dynamic>))
      .toList();
}

TextAlign _parseTextAlign(String? value) {
  return switch (value) {
    'Center' => TextAlign.center,
    'Right' => TextAlign.right,
    'Justify' => TextAlign.left,
    _ => TextAlign.left,
  };
}
