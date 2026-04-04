import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;

import '../../../pages/reader/widgets/reader_canvas_painter.dart';
import '../data/cached_chapter_data_source.dart';
import '../layout/reader_layout_engine.dart';
import '../models/page_layout.dart';
import '../models/parsed_chapter.dart';
import '../models/render_node.dart';
import 'render_diff_job.dart';
import 'render_diff_metrics.dart';
import 'render_diff_node_inventory.dart';
import 'render_diff_style_signature.dart';
import 'render_diff_text_normalizer.dart';

class RenderDiffCanvasExporter {
  RenderDiffCanvasExporter({ReaderLayoutEngine? engine})
    : _engine = engine ?? const ReaderLayoutEngine();

  final ReaderLayoutEngine _engine;

  Future<RenderDiffBookMetrics> export(RenderDiffJob job) async {
    final dataSource = CachedChapterDataSource(cacheDir: job.cacheDir);
    final book = await dataSource.loadBook();
    final chapterIndices = _resolveChapterIndices(book, job);

    final outputDir = Directory(job.outputDir);
    await outputDir.create(recursive: true);

    final pages = <RenderDiffPageMetric>[];
    final chapterPageCounts = <String, int>{};
    final nodeInventory = <RenderDiffNodeInventoryItem>[];

    for (final chapterIndex in chapterIndices) {
      final chapter = await dataSource.loadChapter(chapterIndex);
      final inventory = RenderDiffNodeInventory.extractChapter(
        chapterIndex: chapter.index,
        nodes: chapter.nodes,
      );
      nodeInventory.addAll(inventory.items);
      final chapterPages = await _renderChapter(
        job,
        chapter,
        outputDir.path,
        inventory.byNode,
      );
      chapterPageCounts[chapterIndex.toString()] = chapterPages.length;
      pages.addAll(chapterPages);
    }

    final metrics = RenderDiffBookMetrics(
      engine: 'canvas',
      epubPath: job.epubPath,
      sampleName: job.sampleName,
      viewportWidth: job.viewportWidth,
      viewportHeight: job.viewportHeight,
      devicePixelRatio: job.devicePixelRatio,
      pages: pages,
      chapterPageCounts: chapterPageCounts,
      nodeInventory: nodeInventory,
    );

    final metricsFile = File(p.join(outputDir.path, 'metrics.json'));
    await metricsFile.writeAsString(metrics.toPrettyJson());
    return metrics;
  }

  List<int> _resolveChapterIndices(ParsedBook book, RenderDiffJob job) {
    final explicit = job.chapterIndices;
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final indices = List<int>.generate(book.chapters.length, (index) => index);
    if (job.maxChapters == null || job.maxChapters! >= indices.length) {
      return indices;
    }
    return indices.take(job.maxChapters!).toList();
  }

  Future<List<RenderDiffPageMetric>> _renderChapter(
    RenderDiffJob job,
    ParsedChapter chapter,
    String outputDir,
    Map<RenderNode, RenderDiffNodeInventoryItem> nodeInventoryByNode,
  ) async {
    final viewport = Size(job.viewportWidth, job.viewportHeight);
    final contentWidth =
        viewport.width - 2 * job.preferences.pageHorizontalPaddingPx;
    final decodedImages = await _engine.decodeImages(
      chapter.nodes,
      contentWidth,
      job.devicePixelRatio,
    );

    final pagination = _engine.paginate(
      chapterIndex: chapter.index,
      nodes: chapter.nodes,
      viewportSize: viewport,
      prefs: job.preferences,
      decodedImages: decodedImages,
      safeAreaTop: 0,
      safeAreaBottom: 0,
    );

    final rawPages = pagination.pages;
    final limit = job.maxPagesPerChapter;
    final pages = limit == null || limit >= rawPages.length
        ? rawPages
        : rawPages.take(limit).toList();

    final chapterDir = Directory(
      p.join(
        outputDir,
        'screenshots',
        'chapter_${chapter.index.toString().padLeft(3, '0')}',
      ),
    );
    await chapterDir.create(recursive: true);

    final metrics = <RenderDiffPageMetric>[];
    for (final page in pages) {
      final fileName =
          'page_${page.pageIndexInChapter.toString().padLeft(3, '0')}.png';
      final absolutePath = p.join(chapterDir.path, fileName);
      final relativePath = p.relative(absolutePath, from: outputDir);
      await _paintPageToFile(page: page, job: job, outputPath: absolutePath);
      metrics.add(
        _buildPageMetric(
          chapterIndex: chapter.index,
          page: page,
          screenshotPath: relativePath,
          nodeInventoryByNode: nodeInventoryByNode,
        ),
      );
    }

    return metrics;
  }

  Future<void> _paintPageToFile({
    required PageLayout page,
    required RenderDiffJob job,
    required String outputPath,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(job.devicePixelRatio, job.devicePixelRatio);
    final painter = ReaderCanvasPainter(
      page: page,
      preferences: job.preferences,
    );
    painter.paint(canvas, Size(job.viewportWidth, job.viewportHeight));

    final image = await recorder.endRecording().toImage(
      (job.viewportWidth * job.devicePixelRatio).round(),
      (job.viewportHeight * job.devicePixelRatio).round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Unable to encode canvas page as PNG.');
    }

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(byteData.buffer.asUint8List());
  }

  RenderDiffPageMetric _buildPageMetric({
    required int chapterIndex,
    required PageLayout page,
    required String screenshotPath,
    required Map<RenderNode, RenderDiffNodeInventoryItem> nodeInventoryByNode,
  }) {
    final grouped = <String, _GroupedPageBlock>{};

    for (final element in page.elements) {
      final inventory = nodeInventoryByNode[element.sourceNode];
      if (inventory == null) {
        continue;
      }
      final group = grouped.putIfAbsent(
        inventory.objectId,
        () => _GroupedPageBlock(
          inventory: inventory,
          sourceNode: element.sourceNode,
        ),
      );
      group.elements.add(element);
    }

    final blocks = <RenderDiffBlockMetric>[];
    final anchors = <RenderDiffAnchor>[];
    final blockEntries = grouped.values.toList()
      ..sort(
        (a, b) =>
            _compareElements(a.elements.first.rect, b.elements.first.rect),
      );

    var order = 0;
    for (final entry in blockEntries) {
      final elements = [...entry.elements]
        ..sort((a, b) => _compareElements(a.rect, b.rect));
      final rect = _unionRect(elements);
      final plainText = _visibleTextForElements(elements);
      final fallbackText = plainText.isEmpty
          ? (entry.inventory.text ?? renderNodePlainText(entry.sourceNode))
          : plainText;
      final normalizedText = RenderDiffTextNormalizer.normalize(fallbackText);
      final lineCount = elements.fold<int>(
        0,
        (sum, element) =>
            sum + (element.ensurePainter()?.computeLineMetrics().length ?? 0),
      );
      final styleSignature = RenderDiffStyleSignature.forLayoutBlock(
        sourceNode: entry.sourceNode,
        elements: elements,
      );
      final kind = elements.any((element) => element.image != null)
          ? 'image'
          : 'text';
      final blockId = 'canvas-$chapterIndex-${page.pageIndexInChapter}-$order';
      final anchorHash = normalizedText.isEmpty
          ? null
          : RenderDiffTextNormalizer.stableHash(
              '$chapterIndex|$kind|$normalizedText',
            );

      final metric = RenderDiffBlockMetric(
        blockId: blockId,
        chapterIndex: chapterIndex,
        pageIndex: page.pageIndexInChapter,
        order: order,
        nodeType: entry.inventory.renderNodeKind,
        kind: kind,
        styleSignature: styleSignature,
        rect: RenderDiffRect(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
        ),
        objectId: entry.inventory.objectId,
        nodePath: entry.inventory.nodePath,
        text: fallbackText.isEmpty ? null : fallbackText,
        normalizedText: normalizedText.isEmpty ? null : normalizedText,
        lineCount: lineCount == 0 ? null : lineCount,
        anchorHash: anchorHash,
      );
      blocks.add(metric);

      if (anchorHash != null) {
        anchors.add(
          RenderDiffAnchor(
            anchorHash: anchorHash,
            chapterIndex: chapterIndex,
            pageIndex: page.pageIndexInChapter,
            order: order,
            nodeType: entry.inventory.renderNodeKind,
            text: fallbackText,
            normalizedText: normalizedText,
            styleSignature: styleSignature,
            rect: metric.rect,
            lineCount: lineCount,
          ),
        );
      }

      order += 1;
    }

    final pageText = RenderDiffTextNormalizer.normalize(
      blocks.map((block) => block.normalizedText).whereType<String>().join(' '),
    );

    return RenderDiffPageMetric(
      chapterIndex: chapterIndex,
      pageIndex: page.pageIndexInChapter,
      screenshotPath: screenshotPath,
      normalizedText: pageText,
      blocks: blocks,
      anchors: anchors,
    );
  }

  int _compareElements(Rect a, Rect b) {
    final topDelta = a.top.compareTo(b.top);
    if (topDelta != 0) {
      return topDelta;
    }
    return a.left.compareTo(b.left);
  }

  Rect _unionRect(List<LayoutElement> elements) {
    var rect = elements.first.rect;
    for (final element in elements.skip(1)) {
      rect = rect.expandToInclude(element.rect);
    }
    return rect;
  }

  String _visibleTextForElements(List<LayoutElement> elements) {
    final fragments = <String>[];
    for (final element in elements) {
      final painterText = element.ensurePainter()?.text?.toPlainText();
      final fragment = painterText ?? element.deferredText;
      if (fragment == null || fragment.isEmpty) {
        continue;
      }
      fragments.add(fragment);
    }
    return fragments.join(' ');
  }
}

class _GroupedPageBlock {
  _GroupedPageBlock({required this.inventory, required this.sourceNode});

  final RenderDiffNodeInventoryItem inventory;
  final RenderNode sourceNode;
  final List<LayoutElement> elements = <LayoutElement>[];
}
