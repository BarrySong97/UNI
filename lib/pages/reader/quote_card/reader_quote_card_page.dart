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
  bool _isPreviewReady = true;
  Object? _heroImageIdentity;

  QuoteCardExportService get _exportService =>
      widget.exportService ?? QuoteCardExportService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPreviewReadiness();
  }

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTabletLayout = constraints.maxWidth >= 900;
                if (isTabletLayout) {
                  return _buildTabletLayout(
                    constraints: constraints,
                    controlsVisible: controlsVisible,
                  );
                }
                return _buildPhoneLayout(
                  constraints: constraints,
                  controlsVisible: controlsVisible,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneLayout({
    required BoxConstraints constraints,
    required bool controlsVisible,
  }) {
    return SizedBox.expand(
      child: Column(
        key: const ValueKey<String>('quote-card-phone-layout'),
        children: <Widget>[
          Expanded(
            child: _buildPreviewPane(
              horizontalPadding: 16,
              verticalPadding: 12,
              bottomPadding: controlsVisible ? 12 : 24,
              previewMaxWidth: 520,
            ),
          ),
          if (controlsVisible)
            QuoteCardEditorPanel(
              key: const ValueKey<String>('quote-card-bottom-editor'),
              draft: _draft,
              mode: QuoteCardEditorPanelMode.bottomSheet,
              onTemplateChanged: (value) {
                _updateDraft(_draft.applyTemplateDefaults(value));
              },
              onBackgroundChanged: (value) {
                _updateDraft(_draft.copyWith(background: value));
              },
              onBackgroundIntensityChanged: (value) {
                _updateDraft(_draft.copyWith(backgroundIntensity: value));
              },
              onImageSourceChanged: (value) {
                _updateDraft(_draft.copyWith(imageSource: value));
              },
              onLayoutChanged: (value) {
                _updateDraft(_draft.copyWith(layout: value));
              },
              onFontPresetChanged: (value) {
                _updateDraft(_draft.copyWith(fontPreset: value));
              },
              onShowBookTitleChanged: (value) {
                _updateDraft(_draft.copyWith(showBookTitle: value));
              },
              onShowAuthorChanged: (value) {
                _updateDraft(_draft.copyWith(showAuthor: value));
              },
              onShowChapterTitleChanged: (value) {
                _updateDraft(_draft.copyWith(showChapterTitle: value));
              },
              onShowPageLabelChanged: (value) {
                _updateDraft(_draft.copyWith(showPageLabel: value));
              },
              onShowCollectionLabelChanged: (value) {
                _updateDraft(_draft.copyWith(showCollectionLabel: value));
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout({
    required BoxConstraints constraints,
    required bool controlsVisible,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Row(
        key: const ValueKey<String>('quote-card-tablet-layout'),
        children: <Widget>[
          if (controlsVisible)
            Expanded(
              child: QuoteCardEditorPanel(
                key: const ValueKey<String>('quote-card-side-editor'),
                draft: _draft,
                mode: QuoteCardEditorPanelMode.sidePanel,
                onTemplateChanged: (value) {
                  _updateDraft(_draft.applyTemplateDefaults(value));
                },
                onBackgroundChanged: (value) {
                  _updateDraft(_draft.copyWith(background: value));
                },
                onBackgroundIntensityChanged: (value) {
                  _updateDraft(_draft.copyWith(backgroundIntensity: value));
                },
                onImageSourceChanged: (value) {
                  _updateDraft(_draft.copyWith(imageSource: value));
                },
                onLayoutChanged: (value) {
                  _updateDraft(_draft.copyWith(layout: value));
                },
                onFontPresetChanged: (value) {
                  _updateDraft(_draft.copyWith(fontPreset: value));
                },
                onShowBookTitleChanged: (value) {
                  _updateDraft(_draft.copyWith(showBookTitle: value));
                },
                onShowAuthorChanged: (value) {
                  _updateDraft(_draft.copyWith(showAuthor: value));
                },
                onShowChapterTitleChanged: (value) {
                  _updateDraft(_draft.copyWith(showChapterTitle: value));
                },
                onShowPageLabelChanged: (value) {
                  _updateDraft(_draft.copyWith(showPageLabel: value));
                },
                onShowCollectionLabelChanged: (value) {
                  _updateDraft(_draft.copyWith(showCollectionLabel: value));
                },
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 24),
          Expanded(
            child: Center(
              child: _buildPreviewPane(
                horizontalPadding: 0,
                verticalPadding: 0,
                bottomPadding: 0,
                previewMaxWidth: 580,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPane({
    required double horizontalPadding,
    required double verticalPadding,
    required double bottomPadding,
    required double previewMaxWidth,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        horizontalPadding,
        bottomPadding,
      ),
      child: Center(
        child: RepaintBoundary(
          key: _previewBoundaryKey,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: previewMaxWidth),
            child: QuoteCardPreview(payload: widget.payload, draft: _draft),
          ),
        ),
      ),
    );
  }

  void _updateDraft(QuoteCardDraft nextDraft) {
    setState(() {
      _draft = nextDraft;
    });
    _syncPreviewReadiness();
  }

  Future<void> _syncPreviewReadiness() async {
    final heroProvider = _draft.template.family == QuoteCardTemplateFamily.image
        ? resolveQuoteCardHeroImageProvider(
            payload: widget.payload,
            draft: _draft,
          )
        : null;
    final identity = heroProvider == null
        ? 'gradient'
        : '${heroProvider.runtimeType}-${heroProvider.hashCode}';

    if (_heroImageIdentity == identity && _isPreviewReady) {
      return;
    }
    _heroImageIdentity = identity;

    if (heroProvider == null) {
      if (_isPreviewReady) return;
      if (!mounted) {
        _isPreviewReady = true;
        return;
      }
      setState(() => _isPreviewReady = true);
      return;
    }

    if (mounted) {
      setState(() => _isPreviewReady = false);
    } else {
      _isPreviewReady = false;
    }

    try {
      await precacheImage(heroProvider, context);
    } catch (_) {
      // The preview has its own visual fallback, so export can still proceed.
    }

    if (!mounted || _heroImageIdentity != identity) {
      return;
    }
    setState(() => _isPreviewReady = true);
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
                _updateDraft(
                  _draft.copyWith(
                    isControlsCollapsed: !_draft.isControlsCollapsed,
                  ),
                );
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
                onPressed: _isExporting || !_isPreviewReady
                    ? null
                    : _showExportActions,
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
    await WidgetsBinding.instance.endOfFrame;
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
