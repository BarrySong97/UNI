import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../services/reader/quote_card/quote_card_export_service.dart';
import '../../../shared/constants/common-design-tokens.dart';
import '../../../shared/constants/form-design-tokens.dart';
import 'models/quote_card_draft.dart';
import 'models/reader_quote_card_payload.dart';
import 'widgets/quote_card_editor_panel.dart';
import 'widgets/quote_card_preview.dart';

class ReaderQuoteCardPage extends StatefulWidget {
  const ReaderQuoteCardPage({
    super.key,
    required this.payload,
    this.exportService,
  });

  final ReaderQuoteCardPayload payload;
  final QuoteCardExportService? exportService;

  static Future<void> show({
    required BuildContext context,
    required ReaderQuoteCardPayload payload,
    QuoteCardExportService? exportService,
  }) {
    final mediaQuery = MediaQuery.of(context);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      enableDrag: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.16),
      constraints: BoxConstraints.tight(mediaQuery.size),
      builder: (_) {
        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: SizedBox.expand(
            child: ReaderQuoteCardPage(
              payload: payload,
              exportService: exportService,
            ),
          ),
        );
      },
    );
  }

  @override
  State<ReaderQuoteCardPage> createState() => _ReaderQuoteCardPageState();
}

class _ReaderQuoteCardPageState extends State<ReaderQuoteCardPage> {
  final GlobalKey _previewBoundaryKey = GlobalKey();
  QuoteCardDraft _draft = const QuoteCardDraft();
  bool _isExporting = false;

  QuoteCardExportService get _exportService =>
      widget.exportService ?? QuoteCardExportService();

  @override
  Widget build(BuildContext context) {
    final controlsVisible = !_draft.isControlsCollapsed;
    final topInset = MediaQuery.of(context).padding.top;

    return Material(
      color: CommonDesignTokens.pageBackground,
      child: Column(
        children: <Widget>[
          SizedBox(height: topInset + 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: CommonDesignTokens.borderColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 4),
          _buildTopBar(controlsVisible),
          Expanded(
            child: SizedBox.expand(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final horizontalPadding = constraints.maxWidth >= 900
                            ? 32.0
                            : 16.0;
                        final previewMaxWidth = constraints.maxWidth >= 900
                            ? 560.0
                            : 520.0;

                        return Center(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              12,
                              horizontalPadding,
                              controlsVisible ? 12 : 24,
                            ),
                            child: RepaintBoundary(
                              key: _previewBoundaryKey,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: previewMaxWidth,
                                ),
                                child: QuoteCardPreview(
                                  payload: widget.payload,
                                  draft: _draft,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (controlsVisible)
                    QuoteCardEditorPanel(
                      draft: _draft,
                      onTemplateChanged: (value) {
                        setState(
                          () => _draft = _draft.copyWith(template: value),
                        );
                      },
                      onBackgroundChanged: (value) {
                        setState(
                          () => _draft = _draft.copyWith(background: value),
                        );
                      },
                      onLayoutChanged: (value) {
                        setState(() => _draft = _draft.copyWith(layout: value));
                      },
                      onFontPresetChanged: (value) {
                        setState(
                          () => _draft = _draft.copyWith(fontPreset: value),
                        );
                      },
                      onShowBookTitleChanged: (value) {
                        setState(
                          () => _draft = _draft.copyWith(showBookTitle: value),
                        );
                      },
                      onShowAuthorChanged: (value) {
                        setState(
                          () => _draft = _draft.copyWith(showAuthor: value),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool controlsVisible) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: SizedBox(
        height: CommonDesignTokens.topBarHeight,
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: CommonDesignTokens.textPrimary,
              ),
              tooltip: 'Close',
            ),
            const Expanded(
              child: Text(
                'Quote Card',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: CommonDesignTokens.textPrimary,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey<String>('quote-card-toggle-controls'),
              tooltip: controlsVisible ? 'Hide controls' : 'Show controls',
              onPressed: () {
                setState(() {
                  _draft = _draft.copyWith(
                    isControlsCollapsed: !_draft.isControlsCollapsed,
                  );
                });
              },
              icon: Icon(
                controlsVisible ? Icons.tune_rounded : Icons.tune_outlined,
                color: CommonDesignTokens.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              height: 38,
              child: FilledButton(
                key: const ValueKey<String>('quote-card-export-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: FormDesignTokens.buttonBg,
                  foregroundColor: FormDesignTokens.buttonText,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: _isExporting ? null : _showExportActions,
                child: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: FormDesignTokens.buttonText,
                        ),
                      )
                    : const Text(
                        'Export',
                        style: TextStyle(
                          fontSize: FormDesignTokens.buttonFontSize,
                          fontWeight: FormDesignTokens.buttonFontWeight,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExportActions() async {
    final action = await showModalBottomSheet<_QuoteCardExportAction>(
      context: context,
      backgroundColor: CommonDesignTokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: CommonDesignTokens.borderColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ListTile(
                key: const ValueKey<String>('quote-card-save-action'),
                leading: const Icon(
                  Icons.download_rounded,
                  color: CommonDesignTokens.textPrimary,
                ),
                title: const Text(
                  'Save PNG',
                  style: TextStyle(color: CommonDesignTokens.textPrimary),
                ),
                onTap: () {
                  Navigator.of(context).pop(_QuoteCardExportAction.save);
                },
              ),
              ListTile(
                key: const ValueKey<String>('quote-card-share-action'),
                leading: const Icon(
                  Icons.ios_share_rounded,
                  color: CommonDesignTokens.textPrimary,
                ),
                title: const Text(
                  'Share PNG',
                  style: TextStyle(color: CommonDesignTokens.textPrimary),
                ),
                onTap: () {
                  Navigator.of(context).pop(_QuoteCardExportAction.share);
                },
              ),
            ],
          ),
        );
      },
    );
    if (action == null || !mounted) return;

    setState(() => _isExporting = true);
    try {
      final bytes = await _capturePngBytes();
      final fileName = _exportService.buildFileName(
        bookTitle: widget.payload.bookTitle,
      );

      if (action == _QuoteCardExportAction.save) {
        final path = await _exportService.savePng(
          bytes: bytes,
          fileName: fileName,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved to $path')));
      } else {
        await _exportService.sharePng(bytes: bytes, fileName: fileName);
      }
    } catch (_) {
      if (!mounted) return;
      final failedMessage = switch (action) {
        _QuoteCardExportAction.save => 'Failed to save quote card.',
        _QuoteCardExportAction.share => 'Failed to share quote card.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failedMessage)));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<Uint8List> _capturePngBytes() async {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final boundary =
        _previewBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Quote card boundary is not ready.');
    }
    final pixelRatio = QuoteCardPreview.designWidth / boundary.size.width;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode quote card PNG.');
    }
    return byteData.buffer.asUint8List();
  }
}

enum _QuoteCardExportAction { save, share }
