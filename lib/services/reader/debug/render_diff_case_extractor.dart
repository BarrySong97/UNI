import 'dart:ui' show TextAlign;

import '../models/render_node.dart';
import 'render_diff_text_normalizer.dart';

class RenderDiffExtractedCase {
  const RenderDiffExtractedCase({
    required this.blockCaseHint,
    required this.featureCaseHints,
    required this.observedCaseHints,
    required this.rawNodeSummary,
    this.text,
    this.normalizedText,
    this.imageSignature,
  });

  final String blockCaseHint;
  final List<String> featureCaseHints;
  final List<String> observedCaseHints;
  final Map<String, dynamic> rawNodeSummary;
  final String? text;
  final String? normalizedText;
  final String? imageSignature;
}

class RenderDiffCaseExtractor {
  const RenderDiffCaseExtractor._();

  static RenderDiffExtractedCase extract(
    RenderNode node, {
    bool isNestedList = false,
  }) {
    return switch (node) {
      ParagraphNode() => _extractParagraph(node),
      HeadingNode() => _extractHeading(node),
      ListNode() => _extractList(node, isNestedList: isNestedList),
      TableNode() => _extractTable(node),
      BlockQuoteNode() => _extractBlockQuote(node),
      CodeBlockNode() => _extractCodeBlock(node),
      ImageNode() => _extractImage(node),
      HorizontalRuleNode() => const RenderDiffExtractedCase(
        blockCaseHint: 'block.horizontal_rule',
        featureCaseHints: <String>[],
        observedCaseHints: <String>['block.horizontal_rule'],
        rawNodeSummary: <String, dynamic>{'kind': 'horizontal_rule'},
      ),
      TextNode() => _extractBareText(node),
      LineBreakNode() => const RenderDiffExtractedCase(
        blockCaseHint: 'block.bare_text_wrapped_paragraph',
        featureCaseHints: <String>['inline.line_break'],
        observedCaseHints: <String>[
          'block.bare_text_wrapped_paragraph',
          'inline.line_break',
        ],
        rawNodeSummary: <String, dynamic>{'kind': 'line_break_only'},
        text: '\n',
        normalizedText: '',
      ),
    };
  }

  static RenderDiffExtractedCase _extractParagraph(ParagraphNode node) {
    final featureCases = <String>{..._layoutCasesForParagraph(node)};
    featureCases.addAll(_inlineFeatureCases(node.children));
    final text = renderNodePlainText(node);
    return RenderDiffExtractedCase(
      blockCaseHint: 'block.paragraph',
      featureCaseHints: _sorted(featureCases),
      observedCaseHints: _sorted(<String>{'block.paragraph', ...featureCases}),
      rawNodeSummary: <String, dynamic>{
        'align': _textAlignName(node.align),
        'marginTopEm': node.marginTopEm,
        'marginBottomEm': node.marginBottomEm,
        'marginLeftEm': node.marginLeftEm,
        'marginRightEm': node.marginRightEm,
        'textIndentEm': node.textIndentEm,
        'lineHeightEm': node.lineHeightEm,
        'paddingEm': node.paddingEm,
        'colorHex': _hex(node.color),
        'backgroundHex': _hex(node.backgroundColor),
      },
      text: text,
      normalizedText: RenderDiffTextNormalizer.normalize(text),
    );
  }

  static RenderDiffExtractedCase _extractHeading(HeadingNode node) {
    final featureCases = <String>{..._layoutCasesForHeading(node)};
    featureCases.addAll(_inlineFeatureCases(node.children));
    final blockCase = 'block.heading.h${node.level.clamp(1, 6)}';
    final text = renderNodePlainText(node);
    return RenderDiffExtractedCase(
      blockCaseHint: blockCase,
      featureCaseHints: _sorted(featureCases),
      observedCaseHints: _sorted(<String>{blockCase, ...featureCases}),
      rawNodeSummary: <String, dynamic>{
        'level': node.level,
        'align': _textAlignName(node.align),
        'marginTopEm': node.marginTopEm,
        'marginBottomEm': node.marginBottomEm,
        'marginLeftEm': node.marginLeftEm,
        'marginRightEm': node.marginRightEm,
        'textIndentEm': node.textIndentEm,
        'lineHeightEm': node.lineHeightEm,
        'paddingEm': node.paddingEm,
        'colorHex': _hex(node.color),
        'backgroundHex': _hex(node.backgroundColor),
      },
      text: text,
      normalizedText: RenderDiffTextNormalizer.normalize(text),
    );
  }

  static RenderDiffExtractedCase _extractList(
    ListNode node, {
    required bool isNestedList,
  }) {
    final featureCases = <String>{};
    if (node.listStyle != null) {
      featureCases.addAll(_listStyleCase(node.listStyle));
    }

    final hasNestedList = node.items.any(
      (item) => item.subNodes.any((subNode) => subNode is ListNode),
    );
    final observedCases = <String>{
      isNestedList
          ? 'block.list.nested'
          : (node.ordered ? 'block.list.ol' : 'block.list.ul'),
      ...featureCases,
    };
    if (hasNestedList) {
      observedCases.add('block.list.nested');
    }

    final fragments = <String>[];
    for (final item in node.items) {
      for (final child in item.children) {
        fragments.add(renderNodePlainText(child));
      }
    }
    final text = fragments.join(' ').trim();

    return RenderDiffExtractedCase(
      blockCaseHint: isNestedList
          ? 'block.list.nested'
          : (node.ordered ? 'block.list.ol' : 'block.list.ul'),
      featureCaseHints: _sorted(featureCases),
      observedCaseHints: _sorted(observedCases),
      rawNodeSummary: <String, dynamic>{
        'ordered': node.ordered,
        'listStyle': node.listStyle,
        'itemCount': node.items.length,
        'hasNestedList': hasNestedList,
      },
      text: text.isEmpty ? null : text,
      normalizedText: text.isEmpty
          ? null
          : RenderDiffTextNormalizer.normalize(text),
    );
  }

  static RenderDiffExtractedCase _extractTable(TableNode node) {
    final featureCases = <String>{};
    final observedCases = <String>{'block.table.basic'};
    if ((node.caption ?? const <RenderNode>[]).isNotEmpty) {
      observedCases.add('block.table.caption');
    }

    var hasHeaderRow = false;
    var hasColspan = false;
    var hasRowspan = false;
    var hasBorder = false;
    var hasCellBackground = false;
    var hasVerticalAlign = false;

    final fragments = <String>[];
    for (final row in node.rows) {
      if (row.isHeader) {
        hasHeaderRow = true;
      }
      for (final cell in row.cells) {
        if ((cell.colspan ?? 1) > 1) {
          hasColspan = true;
        }
        if ((cell.rowspan ?? 1) > 1) {
          hasRowspan = true;
        }
        if (cell.border != null) {
          hasBorder = true;
        }
        if (cell.backgroundColor != null) {
          hasCellBackground = true;
        }
        if (cell.verticalAlign != null && cell.verticalAlign != 'middle') {
          hasVerticalAlign = true;
        }
        for (final child in cell.children) {
          fragments.add(renderNodePlainText(child));
        }
      }
    }

    if (hasHeaderRow) {
      observedCases.add('block.table.header_row');
    }
    if (hasColspan) {
      observedCases.add('block.table.colspan');
    }
    if (hasRowspan) {
      observedCases.add('block.table.rowspan');
    }
    if (hasBorder) {
      featureCases.add('layout.table.border');
    }
    if (hasCellBackground) {
      featureCases.add('layout.table.cell_background');
    }
    if (hasVerticalAlign) {
      featureCases.add('layout.table.vertical_align');
    }

    final captionText = (node.caption ?? const <RenderNode>[])
        .map(renderNodePlainText)
        .join(' ');
    final text = [
      captionText,
      ...fragments,
    ].where((fragment) => fragment.trim().isNotEmpty).join(' ');

    return RenderDiffExtractedCase(
      blockCaseHint: 'block.table.basic',
      featureCaseHints: _sorted(featureCases),
      observedCaseHints: _sorted(<String>{...observedCases, ...featureCases}),
      rawNodeSummary: <String, dynamic>{
        'rowCount': node.rows.length,
        'captionText': captionText.isEmpty ? null : captionText,
        'hasHeaderRow': hasHeaderRow,
        'hasColspan': hasColspan,
        'hasRowspan': hasRowspan,
        'hasBorder': hasBorder,
        'hasCellBackground': hasCellBackground,
        'hasVerticalAlign': hasVerticalAlign,
      },
      text: text.isEmpty ? null : text,
      normalizedText: text.isEmpty
          ? null
          : RenderDiffTextNormalizer.normalize(text),
    );
  }

  static RenderDiffExtractedCase _extractBlockQuote(BlockQuoteNode node) {
    final featureCases = <String>{
      'layout.margin',
      ..._inlineFeatureCases(node.children),
    };
    if (node.backgroundColor != null) {
      featureCases.add('layout.background_color');
    }
    final text = renderNodePlainText(node);
    return RenderDiffExtractedCase(
      blockCaseHint: 'block.blockquote',
      featureCaseHints: _sorted(featureCases),
      observedCaseHints: _sorted(<String>{'block.blockquote', ...featureCases}),
      rawNodeSummary: <String, dynamic>{
        'marginTopEm': node.marginTopEm,
        'marginBottomEm': node.marginBottomEm,
        'marginLeftEm': node.marginLeftEm,
        'marginRightEm': node.marginRightEm,
        'backgroundHex': _hex(node.backgroundColor),
      },
      text: text,
      normalizedText: RenderDiffTextNormalizer.normalize(text),
    );
  }

  static RenderDiffExtractedCase _extractCodeBlock(CodeBlockNode node) {
    final children = node.children.isNotEmpty
        ? node.children
        : <RenderNode>[TextNode(content: node.content, fontSizeEm: 0.85)];
    final featureCases = <String>{
      'layout.background_color',
      'layout.padding',
      'inline.inline_code',
      ..._inlineFeatureCases(children),
    };
    final text = renderNodePlainText(
      node.children.isNotEmpty ? node : ParagraphNode(children: children),
    );
    return RenderDiffExtractedCase(
      blockCaseHint: 'block.code.pre',
      featureCaseHints: _sorted(featureCases),
      observedCaseHints: _sorted(<String>{'block.code.pre', ...featureCases}),
      rawNodeSummary: <String, dynamic>{
        'paddingEm': node.paddingEm,
        'backgroundHex': _hex(node.backgroundColor),
        'usesLegacyContent': node.children.isEmpty,
      },
      text: text,
      normalizedText: RenderDiffTextNormalizer.normalize(text),
    );
  }

  static RenderDiffExtractedCase _extractImage(ImageNode node) {
    final featureCases = <String>{};
    if (node.widthHint != null) {
      featureCases.add('layout.image.width_hint');
    }
    if ((node.widthPx ?? 0) > 0 && (node.heightPx ?? 0) > 0) {
      featureCases.add('layout.image.native_size');
    }
    return RenderDiffExtractedCase(
      blockCaseHint: 'block.image',
      featureCaseHints: _sorted(featureCases),
      observedCaseHints: _sorted(<String>{'block.image', ...featureCases}),
      rawNodeSummary: <String, dynamic>{
        'alt': node.alt,
        'widthHint': node.widthHint,
        'widthPx': node.widthPx,
        'heightPx': node.heightPx,
      },
      text: node.alt,
      normalizedText: node.alt == null
          ? null
          : RenderDiffTextNormalizer.normalize(node.alt!),
      imageSignature: _buildImageSignature(
        alt: node.alt,
        width: node.widthPx,
        height: node.heightPx,
      ),
    );
  }

  static RenderDiffExtractedCase _extractBareText(TextNode node) {
    final featureCases = <String>{
      ..._inlineFeatureCases(<RenderNode>[node]),
    };
    final text = node.content;
    return RenderDiffExtractedCase(
      blockCaseHint: 'block.bare_text_wrapped_paragraph',
      featureCaseHints: _sorted(featureCases),
      observedCaseHints: _sorted(<String>{
        'block.bare_text_wrapped_paragraph',
        ...featureCases,
      }),
      rawNodeSummary: <String, dynamic>{
        'nodeIndex': node.nodeIndex,
        'colorHex': _hex(node.color),
        'backgroundHex': _hex(node.backgroundColor),
      },
      text: text,
      normalizedText: RenderDiffTextNormalizer.normalize(text),
    );
  }

  static Set<String> _layoutCasesForParagraph(ParagraphNode node) {
    final cases = <String>{_alignCase(node.align)};
    if (_hasAnyPositive(
      node.marginTopEm,
      node.marginBottomEm,
      node.marginLeftEm,
      node.marginRightEm,
    )) {
      cases.add('layout.margin');
    }
    if ((node.textIndentEm ?? 0) > 0) {
      cases.add('layout.text_indent');
    }
    if ((node.lineHeightEm ?? 0) > 0) {
      cases.add('layout.line_height');
    }
    if ((node.paddingEm ?? 0) > 0) {
      cases.add('layout.padding');
    }
    if (node.color != null) {
      cases.add('layout.text_color');
    }
    if (node.backgroundColor != null) {
      cases.add('layout.background_color');
    }
    return cases;
  }

  static Set<String> _layoutCasesForHeading(HeadingNode node) {
    final cases = <String>{_alignCase(node.align)};
    if (_hasAnyPositive(
      node.marginTopEm,
      node.marginBottomEm,
      node.marginLeftEm,
      node.marginRightEm,
    )) {
      cases.add('layout.margin');
    }
    if ((node.textIndentEm ?? 0) > 0) {
      cases.add('layout.text_indent');
    }
    if ((node.lineHeightEm ?? 0) > 0) {
      cases.add('layout.line_height');
    }
    if ((node.paddingEm ?? 0) > 0) {
      cases.add('layout.padding');
    }
    if (node.color != null) {
      cases.add('layout.text_color');
    }
    if (node.backgroundColor != null) {
      cases.add('layout.background_color');
    }
    return cases;
  }

  static Set<String> _inlineFeatureCases(List<RenderNode> nodes) {
    final cases = <String>{};
    for (final node in nodes) {
      switch (node) {
        case TextNode():
          if (node.bold) {
            cases.add('inline.bold');
          }
          if (node.italic) {
            cases.add('inline.italic');
          }
          if (node.underline) {
            cases.add('inline.underline');
          }
          if (node.lineThrough) {
            cases.add('inline.strikethrough');
          }
          if (node.href != null && node.href!.isNotEmpty) {
            cases.add('inline.link');
          }
          if (node.superscript) {
            cases.add('inline.superscript');
          }
          if (node.subscript) {
            cases.add('inline.subscript');
          }
          if (node.fontSizeEm <= 0.81 && !node.superscript && !node.subscript) {
            cases.add('inline.small');
          }
          if (node.backgroundColor != null) {
            cases.add('inline.mark');
          }
          if (node.color != null) {
            cases.add('layout.text_color');
          }
          break;
        case LineBreakNode():
          cases.add('inline.line_break');
          break;
        case ImageNode():
          cases.add('inline.inline_image_alt_fallback');
          break;
        case ParagraphNode():
          cases.addAll(_inlineFeatureCases(node.children));
          break;
        case HeadingNode():
          cases.addAll(_inlineFeatureCases(node.children));
          break;
        case BlockQuoteNode():
          cases.addAll(_inlineFeatureCases(node.children));
          break;
        case CodeBlockNode():
          if (node.children.isNotEmpty) {
            cases.addAll(_inlineFeatureCases(node.children));
          }
          break;
        case ListNode():
          for (final item in node.items) {
            cases.addAll(_inlineFeatureCases(item.children));
          }
          break;
        case TableNode():
          for (final row in node.rows) {
            for (final cell in row.cells) {
              cases.addAll(_inlineFeatureCases(cell.children));
            }
          }
          break;
        case HorizontalRuleNode():
          break;
      }
    }
    return cases;
  }

  static String _alignCase(TextAlign align) {
    return switch (align) {
      TextAlign.center => 'layout.align.center',
      TextAlign.right || TextAlign.end => 'layout.align.right',
      TextAlign.justify => 'layout.align.justify',
      _ => 'layout.align.left',
    };
  }

  static Iterable<String> _listStyleCase(String? listStyle) {
    return switch ((listStyle ?? '').toLowerCase()) {
      'disc' => const <String>['layout.list_style.disc'],
      'circle' => const <String>['layout.list_style.circle'],
      'square' => const <String>['layout.list_style.square'],
      'decimal' => const <String>['layout.list_style.decimal'],
      'lower-alpha' => const <String>['layout.list_style.lower_alpha'],
      'upper-alpha' => const <String>['layout.list_style.upper_alpha'],
      'lower-roman' => const <String>['layout.list_style.lower_roman'],
      'upper-roman' => const <String>['layout.list_style.upper_roman'],
      _ => const <String>[],
    };
  }

  static bool _hasAnyPositive(double a, double b, double c, double d) {
    return a > 0 || b > 0 || c > 0 || d > 0;
  }

  static List<String> _sorted(Iterable<String> values) {
    final result = values.toSet().toList()..sort();
    return result;
  }

  static String _textAlignName(TextAlign align) {
    return switch (align) {
      TextAlign.center => 'center',
      TextAlign.right || TextAlign.end => 'right',
      TextAlign.justify => 'justify',
      _ => 'left',
    };
  }

  static String? _hex(int? color) {
    if (color == null) {
      return null;
    }
    return color.toRadixString(16).padLeft(8, '0');
  }

  static String? _buildImageSignature({
    required String? alt,
    required int? width,
    required int? height,
  }) {
    final canonicalAlt = _canonicalize(alt ?? '');
    final safeWidth = width ?? 0;
    final safeHeight = height ?? 0;
    if (canonicalAlt.isEmpty && safeWidth <= 0 && safeHeight <= 0) {
      return null;
    }
    return '$canonicalAlt|${safeWidth}x$safeHeight';
  }

  static String _canonicalize(String text) {
    final normalized = RenderDiffTextNormalizer.normalize(text).toLowerCase();
    final buffer = StringBuffer();
    for (final rune in normalized.runes) {
      if (_isCanonicalRune(rune)) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  static bool _isCanonicalRune(int rune) {
    return (rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        (rune >= 0x4E00 && rune <= 0x9FFF);
  }
}
