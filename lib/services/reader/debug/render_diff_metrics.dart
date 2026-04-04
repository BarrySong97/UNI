import 'dart:convert';

class RenderDiffRect {
  const RenderDiffRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  Map<String, dynamic> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  factory RenderDiffRect.fromJson(Map<String, dynamic> json) => RenderDiffRect(
    left: (json['left'] as num?)?.toDouble() ?? 0,
    top: (json['top'] as num?)?.toDouble() ?? 0,
    width: (json['width'] as num?)?.toDouble() ?? 0,
    height: (json['height'] as num?)?.toDouble() ?? 0,
  );
}

class RenderDiffBlockMetric {
  const RenderDiffBlockMetric({
    required this.blockId,
    required this.chapterIndex,
    required this.pageIndex,
    required this.order,
    required this.nodeType,
    required this.kind,
    required this.styleSignature,
    required this.rect,
    this.objectId,
    this.nodePath,
    this.text,
    this.normalizedText,
    this.lineCount,
    this.anchorHash,
  });

  final String blockId;
  final int chapterIndex;
  final int pageIndex;
  final int order;
  final String nodeType;
  final String kind;
  final String styleSignature;
  final RenderDiffRect rect;
  final String? objectId;
  final String? nodePath;
  final String? text;
  final String? normalizedText;
  final int? lineCount;
  final String? anchorHash;

  Map<String, dynamic> toJson() => {
    'blockId': blockId,
    'chapterIndex': chapterIndex,
    'pageIndex': pageIndex,
    'order': order,
    'nodeType': nodeType,
    'kind': kind,
    'styleSignature': styleSignature,
    'rect': rect.toJson(),
    'objectId': objectId,
    'nodePath': nodePath,
    'text': text,
    'normalizedText': normalizedText,
    'lineCount': lineCount,
    'anchorHash': anchorHash,
  };

  factory RenderDiffBlockMetric.fromJson(Map<String, dynamic> json) =>
      RenderDiffBlockMetric(
        blockId: json['blockId'] as String? ?? '',
        chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
        pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
        order: (json['order'] as num?)?.toInt() ?? 0,
        nodeType: json['nodeType'] as String? ?? '',
        kind: json['kind'] as String? ?? 'text',
        styleSignature: json['styleSignature'] as String? ?? '',
        rect: RenderDiffRect.fromJson(
          (json['rect'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
        objectId: json['objectId'] as String?,
        nodePath: json['nodePath'] as String?,
        text: json['text'] as String?,
        normalizedText: json['normalizedText'] as String?,
        lineCount: (json['lineCount'] as num?)?.toInt(),
        anchorHash: json['anchorHash'] as String?,
      );
}

class RenderDiffAnchor {
  const RenderDiffAnchor({
    required this.anchorHash,
    required this.chapterIndex,
    required this.pageIndex,
    required this.order,
    required this.nodeType,
    required this.text,
    required this.normalizedText,
    required this.styleSignature,
    required this.rect,
    required this.lineCount,
  });

  final String anchorHash;
  final int chapterIndex;
  final int pageIndex;
  final int order;
  final String nodeType;
  final String text;
  final String normalizedText;
  final String styleSignature;
  final RenderDiffRect rect;
  final int lineCount;

  Map<String, dynamic> toJson() => {
    'anchorHash': anchorHash,
    'chapterIndex': chapterIndex,
    'pageIndex': pageIndex,
    'order': order,
    'nodeType': nodeType,
    'text': text,
    'normalizedText': normalizedText,
    'styleSignature': styleSignature,
    'rect': rect.toJson(),
    'lineCount': lineCount,
  };

  factory RenderDiffAnchor.fromJson(Map<String, dynamic> json) =>
      RenderDiffAnchor(
        anchorHash: json['anchorHash'] as String? ?? '',
        chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
        pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
        order: (json['order'] as num?)?.toInt() ?? 0,
        nodeType: json['nodeType'] as String? ?? '',
        text: json['text'] as String? ?? '',
        normalizedText: json['normalizedText'] as String? ?? '',
        styleSignature: json['styleSignature'] as String? ?? '',
        rect: RenderDiffRect.fromJson(
          (json['rect'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
        lineCount: (json['lineCount'] as num?)?.toInt() ?? 0,
      );
}

class RenderDiffNodeInventoryItem {
  const RenderDiffNodeInventoryItem({
    required this.objectId,
    required this.chapterIndex,
    required this.nodeOrdinal,
    required this.nodePath,
    required this.renderNodeKind,
    required this.blockCaseHint,
    required this.featureCaseHints,
    required this.observedCaseHints,
    required this.rawNodeSummary,
    this.text,
    this.normalizedText,
    this.imageSignature,
  });

  final String objectId;
  final int chapterIndex;
  final int nodeOrdinal;
  final String nodePath;
  final String renderNodeKind;
  final String blockCaseHint;
  final List<String> featureCaseHints;
  final List<String> observedCaseHints;
  final Map<String, dynamic> rawNodeSummary;
  final String? text;
  final String? normalizedText;
  final String? imageSignature;

  Map<String, dynamic> toJson() => {
    'objectId': objectId,
    'chapterIndex': chapterIndex,
    'nodeOrdinal': nodeOrdinal,
    'nodePath': nodePath,
    'renderNodeKind': renderNodeKind,
    'blockCaseHint': blockCaseHint,
    'featureCaseHints': featureCaseHints,
    'observedCaseHints': observedCaseHints,
    'rawNodeSummary': rawNodeSummary,
    'text': text,
    'normalizedText': normalizedText,
    'imageSignature': imageSignature,
  };

  factory RenderDiffNodeInventoryItem.fromJson(Map<String, dynamic> json) =>
      RenderDiffNodeInventoryItem(
        objectId: json['objectId'] as String? ?? '',
        chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
        nodeOrdinal: (json['nodeOrdinal'] as num?)?.toInt() ?? 0,
        nodePath: json['nodePath'] as String? ?? '',
        renderNodeKind: json['renderNodeKind'] as String? ?? '',
        blockCaseHint: json['blockCaseHint'] as String? ?? '',
        featureCaseHints:
            (json['featureCaseHints'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[],
        observedCaseHints:
            (json['observedCaseHints'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[],
        rawNodeSummary:
            (json['rawNodeSummary'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
        text: json['text'] as String?,
        normalizedText: json['normalizedText'] as String?,
        imageSignature: json['imageSignature'] as String?,
      );
}

class RenderDiffPageMetric {
  const RenderDiffPageMetric({
    required this.chapterIndex,
    required this.pageIndex,
    required this.screenshotPath,
    required this.normalizedText,
    required this.blocks,
    required this.anchors,
  });

  final int chapterIndex;
  final int pageIndex;
  final String screenshotPath;
  final String normalizedText;
  final List<RenderDiffBlockMetric> blocks;
  final List<RenderDiffAnchor> anchors;

  Map<String, dynamic> toJson() => {
    'chapterIndex': chapterIndex,
    'pageIndex': pageIndex,
    'screenshotPath': screenshotPath,
    'normalizedText': normalizedText,
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'anchors': anchors.map((a) => a.toJson()).toList(),
  };

  factory RenderDiffPageMetric.fromJson(Map<String, dynamic> json) =>
      RenderDiffPageMetric(
        chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
        pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
        screenshotPath: json['screenshotPath'] as String? ?? '',
        normalizedText: json['normalizedText'] as String? ?? '',
        blocks:
            (json['blocks'] as List?)
                ?.map(
                  (e) => RenderDiffBlockMetric.fromJson(
                    (e as Map).cast<String, dynamic>(),
                  ),
                )
                .toList() ??
            const [],
        anchors:
            (json['anchors'] as List?)
                ?.map(
                  (e) => RenderDiffAnchor.fromJson(
                    (e as Map).cast<String, dynamic>(),
                  ),
                )
                .toList() ??
            const [],
      );
}

class RenderDiffBookMetrics {
  const RenderDiffBookMetrics({
    required this.engine,
    required this.epubPath,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.devicePixelRatio,
    required this.pages,
    required this.chapterPageCounts,
    required this.nodeInventory,
    this.sampleName,
  });

  final String engine;
  final String epubPath;
  final String? sampleName;
  final double viewportWidth;
  final double viewportHeight;
  final double devicePixelRatio;
  final List<RenderDiffPageMetric> pages;
  final Map<String, int> chapterPageCounts;
  final List<RenderDiffNodeInventoryItem> nodeInventory;

  Map<String, dynamic> toJson() => {
    'engine': engine,
    'epubPath': epubPath,
    'sampleName': sampleName,
    'viewportWidth': viewportWidth,
    'viewportHeight': viewportHeight,
    'devicePixelRatio': devicePixelRatio,
    'pages': pages.map((p) => p.toJson()).toList(),
    'chapterPageCounts': chapterPageCounts,
    'nodeInventory': nodeInventory.map((item) => item.toJson()).toList(),
  };

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  factory RenderDiffBookMetrics.fromJson(Map<String, dynamic> json) =>
      RenderDiffBookMetrics(
        engine: json['engine'] as String? ?? '',
        epubPath: json['epubPath'] as String? ?? '',
        sampleName: json['sampleName'] as String?,
        viewportWidth: (json['viewportWidth'] as num?)?.toDouble() ?? 0,
        viewportHeight: (json['viewportHeight'] as num?)?.toDouble() ?? 0,
        devicePixelRatio: (json['devicePixelRatio'] as num?)?.toDouble() ?? 1.0,
        pages:
            (json['pages'] as List?)
                ?.map(
                  (e) => RenderDiffPageMetric.fromJson(
                    (e as Map).cast<String, dynamic>(),
                  ),
                )
                .toList() ??
            const [],
        chapterPageCounts:
            (json['chapterPageCounts'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), (value as num).toInt()),
            ) ??
            const {},
        nodeInventory:
            (json['nodeInventory'] as List?)
                ?.map(
                  (e) => RenderDiffNodeInventoryItem.fromJson(
                    (e as Map).cast<String, dynamic>(),
                  ),
                )
                .toList() ??
            const [],
      );
}
