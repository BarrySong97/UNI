import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../shared/constants/common-design-tokens.dart';
import '../../../../shared/utils/cover-image-cache.dart';
import '../models/quote_card_draft.dart';
import '../models/reader_quote_card_payload.dart';
import '../quote_card_style_resolver.dart';

class QuoteCardPreview extends StatelessWidget {
  const QuoteCardPreview({
    super.key,
    required this.payload,
    required this.draft,
  });

  final ReaderQuoteCardPayload payload;
  final QuoteCardDraft draft;

  static const double designWidth = 1080;
  static const double designHeight = 1350;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = resolveQuoteCardStyle(draft: draft);
    if (resolvedStyle.family == QuoteCardTemplateFamily.image) {
      return _buildImageCard(resolvedStyle);
    }
    return _buildGradientCard(resolvedStyle);
  }

  Widget _buildGradientCard(QuoteCardResolvedStyle resolvedStyle) {
    final quoteLength = payload.selectedText.trim().length;
    final quoteFontSize = _quoteFontSize(
      length: quoteLength,
      template: draft.template,
      fontPreset: draft.fontPreset,
    );
    final fontFamily = _resolveFontFamily();
    final textColor = _textColorForBackground(draft.background);
    final subtleColor = textColor.withValues(
      alpha: resolvedStyle.metadataOpacity,
    );
    final author = payload.bookAuthor.trim();
    final bookTitle = payload.bookTitle.trim();
    final intensity = _intensityValue(draft.backgroundIntensity);
    final metadataChild = _buildSimpleMetadata(
      resolvedStyle: resolvedStyle,
      subtleColor: subtleColor,
      author: author,
      bookTitle: bookTitle,
      chapterTitle: payload.chapterTitle?.trim() ?? '',
      pageLabel: payload.pageLabel?.trim() ?? '',
      collectionLabel: payload.collectionLabel?.trim() ?? '',
      fontFamily: fontFamily,
      textColor: textColor,
    );
    final borderRadius = BorderRadius.circular(
      CommonDesignTokens.cardRadius + 8,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: designWidth,
              height: designHeight,
              child: Container(
                key: ValueKey<String>(
                  'quote-card-background-${_backgroundKey(draft.background)}',
                ),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  gradient: _backgroundGradient(draft.background),
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: resolvedStyle.showBorder ? 0.72 : 0.46,
                    ),
                    width: resolvedStyle.showBorder ? 1.4 : 1,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _QuoteCardBackdrop(
                      background: draft.background,
                      intensity: intensity,
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: textColor.withValues(
                            alpha:
                                resolvedStyle.surfaceOverlayOpacity * intensity,
                          ),
                        ),
                      ),
                    ),
                    if (resolvedStyle.showTopAccent)
                      Positioned(
                        left: 72,
                        right: 72,
                        top: 72,
                        child: Container(
                          height: 2,
                          color: textColor.withValues(alpha: 0.12),
                        ),
                      ),
                    if (resolvedStyle.showAccentLine)
                      Positioned(
                        left: 70,
                        top: 124,
                        bottom: 220,
                        child: Container(
                          width: 3,
                          color: textColor.withValues(alpha: 0.12),
                        ),
                      ),
                    if (resolvedStyle.showQuoteMark)
                      Positioned(
                        left: draft.template == QuoteCardTemplate.auroraMist
                            ? 82
                            : 72,
                        top: 48,
                        child: Text(
                          '“',
                          style: TextStyle(
                            color: textColor.withValues(
                              alpha: resolvedStyle.quoteMarkOpacity,
                            ),
                            fontSize: resolvedStyle.quoteMarkSize,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            fontFamily: fontFamily,
                          ),
                        ),
                      ),
                    Padding(
                      padding: resolvedStyle.quotePadding,
                      child: Stack(
                        children: <Widget>[
                          Align(
                            alignment: resolvedStyle.quoteAlignment,
                            child: Container(
                              key: const ValueKey<String>(
                                'quote-card-quote-container',
                              ),
                              constraints: BoxConstraints(
                                maxWidth: resolvedStyle.quoteMaxWidth,
                              ),
                              child: Text(
                                payload.selectedText.trim(),
                                key: const ValueKey<String>('quote-card-text'),
                                textAlign: resolvedStyle.quoteTextAlign,
                                maxLines: 10,
                                overflow: TextOverflow.fade,
                                style: TextStyle(
                                  color: textColor,
                                  height: 1.35,
                                  fontSize:
                                      quoteFontSize * resolvedStyle.quoteScale,
                                  fontWeight: resolvedStyle.quoteWeight,
                                  letterSpacing:
                                      resolvedStyle.quoteLetterSpacing,
                                  fontFamily: fontFamily,
                                  fontFamilyFallback: const <String>[
                                    'Georgia',
                                    'serif',
                                    'sans-serif',
                                  ],
                                ),
                              ),
                            ),
                          ),
                          switch (resolvedStyle.metadataLayout) {
                            QuoteCardMetadataLayout.bottomLeft => Positioned(
                              left: 0,
                              bottom: 0,
                              child: metadataChild,
                            ),
                            QuoteCardMetadataLayout.bottomCenter => Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Center(child: metadataChild),
                            ),
                            QuoteCardMetadataLayout.grid =>
                              const SizedBox.shrink(),
                          },
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(QuoteCardResolvedStyle resolvedStyle) {
    final quoteLength = payload.selectedText.trim().length;
    final quoteFontSize = _quoteFontSize(
      length: quoteLength,
      template: draft.template,
      fontPreset: draft.fontPreset,
    );
    final fontFamily = _resolveFontFamily();
    final textColor = _textColorForBackground(draft.background);
    final subtleColor = textColor.withValues(
      alpha: resolvedStyle.metadataOpacity,
    );
    final heroProvider = resolveQuoteCardHeroImageProvider(
      payload: payload,
      draft: draft,
    );
    final imageFlex = ((resolvedStyle.imageHeightFactor ?? 0.52) * 100).round();
    final textFlex = 100 - imageFlex;
    final borderRadius = BorderRadius.circular(
      CommonDesignTokens.cardRadius + 8,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: designWidth,
              height: designHeight,
              child: Container(
                key: ValueKey<String>(
                  'quote-card-image-family-${draft.template.name}',
                ),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: _surfaceColorForBackground(draft.background),
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.04),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      flex: imageFlex,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          if (heroProvider != null)
                            Image(
                              key: const ValueKey<String>(
                                'quote-card-hero-image',
                              ),
                              image: heroProvider,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildImageFallback(),
                            )
                          else
                            _buildImageFallback(),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.transparent,
                                  Colors.black.withValues(
                                    alpha: resolvedStyle.surfaceOverlayOpacity,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: textFlex,
                      child: Container(
                        color: _surfaceColorForBackground(draft.background),
                        child: Padding(
                          padding: resolvedStyle.captionPanelPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                payload.selectedText.trim(),
                                key: const ValueKey<String>('quote-card-text'),
                                textAlign: resolvedStyle.quoteTextAlign,
                                maxLines: resolvedStyle.showMetadataGrid
                                    ? 5
                                    : 6,
                                overflow: TextOverflow.fade,
                                style: TextStyle(
                                  color: textColor,
                                  height: 1.4,
                                  fontSize:
                                      quoteFontSize * resolvedStyle.quoteScale,
                                  fontWeight: resolvedStyle.quoteWeight,
                                  letterSpacing:
                                      resolvedStyle.quoteLetterSpacing,
                                  fontFamily: fontFamily,
                                  fontFamilyFallback: const <String>[
                                    'Georgia',
                                    'serif',
                                    'sans-serif',
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 1,
                                color: textColor.withValues(alpha: 0.08),
                              ),
                              const SizedBox(height: 12),
                              if (resolvedStyle.showMetadataGrid)
                                Expanded(
                                  child: _buildMetadataGrid(
                                    subtleColor: subtleColor,
                                    textColor: textColor,
                                    fontFamily: fontFamily,
                                  ),
                                )
                              else
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: _buildSimpleMetadata(
                                    resolvedStyle: resolvedStyle,
                                    subtleColor: subtleColor,
                                    author: payload.bookAuthor.trim(),
                                    bookTitle: payload.bookTitle.trim(),
                                    chapterTitle:
                                        payload.chapterTitle?.trim() ?? '',
                                    pageLabel: payload.pageLabel?.trim() ?? '',
                                    collectionLabel:
                                        payload.collectionLabel?.trim() ?? '',
                                    fontFamily: fontFamily,
                                    textColor: textColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataGrid({
    required Color subtleColor,
    required Color textColor,
    required String? fontFamily,
  }) {
    final entries = <_MetadataEntry>[
      if (draft.showAuthor && payload.bookAuthor.trim().isNotEmpty)
        _MetadataEntry('AUTHOR', payload.bookAuthor.trim()),
      if (draft.showBookTitle && payload.bookTitle.trim().isNotEmpty)
        _MetadataEntry('BOOK', payload.bookTitle.trim()),
      if (draft.showChapterTitle &&
          (payload.chapterTitle?.trim().isNotEmpty ?? false))
        _MetadataEntry('CHAPTER', payload.chapterTitle!.trim()),
      if (draft.showPageLabel &&
          (payload.pageLabel?.trim().isNotEmpty ?? false))
        _MetadataEntry('PAGE', payload.pageLabel!.trim()),
      if (draft.showCollectionLabel &&
          (payload.collectionLabel?.trim().isNotEmpty ?? false))
        _MetadataEntry('COLLECTION', payload.collectionLabel!.trim()),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          key: const ValueKey<String>('quote-card-metadata-grid'),
          spacing: 12,
          runSpacing: 12,
          children: entries
              .map(
                (entry) => SizedBox(
                  width: itemWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        entry.label,
                        style: TextStyle(
                          color: subtleColor,
                          fontSize: 10,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          fontFamily: fontFamily,
                          fontFamilyFallback: const <String>[
                            'Georgia',
                            'serif',
                            'sans-serif',
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildSimpleMetadata({
    required QuoteCardResolvedStyle resolvedStyle,
    required Color subtleColor,
    required String author,
    required String bookTitle,
    required String chapterTitle,
    required String pageLabel,
    required String collectionLabel,
    required String? fontFamily,
    required Color textColor,
  }) {
    final alignment =
        resolvedStyle.metadataLayout == QuoteCardMetadataLayout.bottomCenter
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign =
        resolvedStyle.metadataLayout == QuoteCardMetadataLayout.bottomCenter
        ? TextAlign.center
        : TextAlign.left;

    final extraLines = <String>[
      if (draft.showChapterTitle && chapterTitle.isNotEmpty) chapterTitle,
      if (draft.showPageLabel && pageLabel.isNotEmpty) pageLabel,
      if (draft.showCollectionLabel && collectionLabel.isNotEmpty)
        collectionLabel,
    ];

    final textBlock = DefaultTextStyle(
      style: TextStyle(
        color: subtleColor,
        fontSize: resolvedStyle.metadataFontSize,
        height: 1.35,
        fontWeight: FontWeight.w500,
        fontStyle: draft.fontPreset == QuoteCardFontPreset.displaySerif
            ? FontStyle.italic
            : FontStyle.normal,
        letterSpacing: draft.template == QuoteCardTemplate.nightGlow ? 0.24 : 0,
        fontFamily: fontFamily,
        fontFamilyFallback: const <String>['Georgia', 'serif', 'sans-serif'],
      ),
      child: Column(
        crossAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (draft.showAuthor && author.isNotEmpty)
            Text(
              author,
              key: const ValueKey<String>('quote-card-author-text'),
              textAlign: textAlign,
            ),
          if (draft.showBookTitle && bookTitle.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: draft.showAuthor && author.isNotEmpty ? 4 : 0,
              ),
              child: Text(
                bookTitle,
                key: const ValueKey<String>('quote-card-book-title-text'),
                textAlign: textAlign,
              ),
            ),
          for (final line in extraLines)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(line, textAlign: textAlign),
            ),
        ],
      ),
    );

    if (resolvedStyle.metadataBackgroundOpacity <= 0) {
      return Padding(
        padding: resolvedStyle.captionPanelPadding,
        child: textBlock,
      );
    }

    return Container(
      padding: resolvedStyle.captionPanelPadding,
      decoration: BoxDecoration(
        color: textColor.withValues(
          alpha: resolvedStyle.metadataBackgroundOpacity,
        ),
        borderRadius: BorderRadius.circular(resolvedStyle.metadataRadius),
        border: Border.all(
          color: textColor.withValues(
            alpha: resolvedStyle.metadataBorderOpacity,
          ),
        ),
      ),
      child: textBlock,
    );
  }

  Widget _buildImageFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _backgroundGradient(draft.background),
      ),
      child: const Center(
        child: Icon(Icons.photo_outlined, size: 32, color: Colors.white70),
      ),
    );
  }

  String? _resolveFontFamily() {
    return switch (draft.fontPreset) {
      QuoteCardFontPreset.reader => payload.readerFontFamily,
      QuoteCardFontPreset.serif => 'serif',
      QuoteCardFontPreset.sans => 'sans-serif',
      QuoteCardFontPreset.displaySerif => 'Georgia',
    };
  }
}

class _QuoteCardBackdrop extends StatelessWidget {
  const _QuoteCardBackdrop({required this.background, required this.intensity});

  final QuoteCardBackgroundPreset background;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final glowColor = switch (background) {
      QuoteCardBackgroundPreset.mist => const Color(0xFFFFFFFF),
      QuoteCardBackgroundPreset.bloom => const Color(0xFFE3C1B4),
      QuoteCardBackgroundPreset.forest => const Color(0xFFA7BFAE),
      QuoteCardBackgroundPreset.sunset => const Color(0xFFE0AF94),
      QuoteCardBackgroundPreset.night => const Color(0xFF68748D),
      QuoteCardBackgroundPreset.archivePaper => const Color(0xFFD8CCBC),
    };

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned(
          top: -90,
          right: -40,
          child: _buildGlow(
            size: 340,
            color: glowColor.withValues(alpha: 0.16 + 0.12 * intensity),
          ),
        ),
        Positioned(
          top: 180,
          left: -80,
          child: _buildGlow(
            size: 280,
            color: glowColor.withValues(alpha: 0.08 + 0.08 * intensity),
          ),
        ),
        Positioned(
          bottom: 220,
          right: 140,
          child: _buildGlow(
            size: 240,
            color: glowColor.withValues(alpha: 0.07 + 0.07 * intensity),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.white.withValues(
                    alpha: background == QuoteCardBackgroundPreset.night
                        ? 0.02
                        : 0.08,
                  ),
                  Colors.transparent,
                  Colors.black.withValues(
                    alpha: background == QuoteCardBackgroundPreset.night
                        ? 0.18
                        : 0.05,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlow({required double size, required Color color}) {
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _MetadataEntry {
  const _MetadataEntry(this.label, this.value);

  final String label;
  final String value;
}

ImageProvider<Object>? resolveQuoteCardHeroImageProvider({
  required ReaderQuoteCardPayload payload,
  required QuoteCardDraft draft,
}) {
  return switch (draft.imageSource) {
    QuoteCardImageSource.bookCover =>
      _bookCoverImageProvider(payload) ??
          const AssetImage('assets/quote_card/artwork_still_life.png'),
    QuoteCardImageSource.artworkStillLife => const AssetImage(
      'assets/quote_card/artwork_still_life.png',
    ),
    QuoteCardImageSource.artworkAbstract => const AssetImage(
      'assets/quote_card/artwork_abstract.png',
    ),
    QuoteCardImageSource.artworkBotanical => const AssetImage(
      'assets/quote_card/artwork_botanical.png',
    ),
  };
}

MemoryImage? _bookCoverImageProvider(ReaderQuoteCardPayload payload) {
  final bytes = CoverImageCache.decode(payload.coverDataUrl);
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  return MemoryImage(bytes);
}

LinearGradient _backgroundGradient(QuoteCardBackgroundPreset background) {
  return switch (background) {
    QuoteCardBackgroundPreset.mist => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFF7F6F3), Color(0xFFECE9E2), Color(0xFFDEDBD5)],
      stops: <double>[0, 0.56, 1],
    ),
    QuoteCardBackgroundPreset.bloom => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFF4EAE2), Color(0xFFE7D6CB), Color(0xFFDCC0B5)],
    ),
    QuoteCardBackgroundPreset.forest => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFF0F3EE), Color(0xFFDDE7DD), Color(0xFFC5D2C5)],
    ),
    QuoteCardBackgroundPreset.sunset => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFF4E6DD), Color(0xFFE8CDC0), Color(0xFFD9B8A0)],
    ),
    QuoteCardBackgroundPreset.night => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF293140), Color(0xFF171D28), Color(0xFF11151C)],
    ),
    QuoteCardBackgroundPreset.archivePaper => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFF2EEE6), Color(0xFFE7DECF), Color(0xFFD6CABB)],
    ),
  };
}

Color _surfaceColorForBackground(QuoteCardBackgroundPreset background) {
  return switch (background) {
    QuoteCardBackgroundPreset.mist => const Color(0xFFF6F3EE),
    QuoteCardBackgroundPreset.bloom => const Color(0xFFF3ECE6),
    QuoteCardBackgroundPreset.forest => const Color(0xFFF0F3EE),
    QuoteCardBackgroundPreset.sunset => const Color(0xFFF6EEE8),
    QuoteCardBackgroundPreset.night => const Color(0xFFF1EEEA),
    QuoteCardBackgroundPreset.archivePaper => const Color(0xFFF3EFE7),
  };
}

Color _textColorForBackground(QuoteCardBackgroundPreset background) {
  return switch (background) {
    QuoteCardBackgroundPreset.night => const Color(0xFFF7F5F2),
    QuoteCardBackgroundPreset.sunset => const Color(0xFF3E2B22),
    _ => CommonDesignTokens.textPrimary,
  };
}

double _quoteFontSize({
  required int length,
  required QuoteCardTemplate template,
  required QuoteCardFontPreset fontPreset,
}) {
  final base = switch (length) {
    <= 60 => 72.0,
    <= 120 => 62.0,
    <= 220 => 54.0,
    _ => 46.0,
  };
  final templateDelta = switch (template) {
    QuoteCardTemplate.nightGlow => 2.0,
    QuoteCardTemplate.galleryFrame => -2.0,
    QuoteCardTemplate.archiveNote => -3.0,
    QuoteCardTemplate.coverColumn => -4.0,
    _ => 0.0,
  };
  final fontDelta = switch (fontPreset) {
    QuoteCardFontPreset.displaySerif => -2.0,
    QuoteCardFontPreset.sans => 1.0,
    _ => 0.0,
  };
  return base + templateDelta + fontDelta;
}

double _intensityValue(QuoteCardBackgroundIntensity intensity) {
  return switch (intensity) {
    QuoteCardBackgroundIntensity.subtle => 0.75,
    QuoteCardBackgroundIntensity.medium => 1.0,
    QuoteCardBackgroundIntensity.strong => 1.35,
  };
}

String _backgroundKey(QuoteCardBackgroundPreset background) {
  return switch (background) {
    QuoteCardBackgroundPreset.mist => 'mist',
    QuoteCardBackgroundPreset.bloom => 'bloom',
    QuoteCardBackgroundPreset.forest => 'forest',
    QuoteCardBackgroundPreset.sunset => 'sunset',
    QuoteCardBackgroundPreset.night => 'night',
    QuoteCardBackgroundPreset.archivePaper => 'archive-paper',
  };
}
