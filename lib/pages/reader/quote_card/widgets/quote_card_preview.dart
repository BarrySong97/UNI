import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../shared/constants/common-design-tokens.dart';
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
    final quoteLength = payload.selectedText.trim().length;
    final quoteFontSize = _quoteFontSize(
      length: quoteLength,
      template: draft.template,
    );
    final fontFamily = _resolveFontFamily();
    final textColor = _textColorForBackground(draft.background);
    final subtleColor = textColor.withValues(
      alpha: resolvedStyle.metadataOpacity,
    );
    final author = payload.bookAuthor.trim();
    final bookTitle = payload.bookTitle.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius + 8),
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
        child: Container(
          key: ValueKey<String>(
            'quote-card-background-${_backgroundKey(draft.background)}',
          ),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            gradient: _backgroundGradient(draft.background),
            borderRadius: BorderRadius.circular(
              CommonDesignTokens.cardRadius + 8,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.46),
              width: 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _QuoteCardBackdrop(background: draft.background),
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
              if (resolvedStyle.showVerticalAccent)
                Positioned(
                  left: 60,
                  top: 120,
                  bottom: 220,
                  child: Container(
                    width: 3,
                    color: textColor.withValues(alpha: 0.12),
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
                        constraints: const BoxConstraints(maxWidth: 840),
                        child: Text(
                          payload.selectedText.trim(),
                          key: const ValueKey<String>('quote-card-text'),
                          textAlign: resolvedStyle.quoteTextAlign,
                          maxLines: 10,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            color: textColor,
                            height: 1.35,
                            fontSize: quoteFontSize,
                            fontWeight:
                                draft.template == QuoteCardTemplate.spotlight
                                ? FontWeight.w600
                                : FontWeight.w500,
                            letterSpacing:
                                draft.template == QuoteCardTemplate.minimal
                                ? 0.2
                                : 0,
                            fontFamily: fontFamily,
                            fontFamilyFallback: const <String>[
                              'serif',
                              'sans-serif',
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: subtleColor,
                          fontSize: resolvedStyle.metadataFontSize,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          fontFamily: fontFamily,
                          fontFamilyFallback: const <String>[
                            'serif',
                            'sans-serif',
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (draft.showAuthor && author.isNotEmpty)
                              Text(
                                author,
                                key: const ValueKey<String>(
                                  'quote-card-author-text',
                                ),
                              ),
                            if (draft.showBookTitle && bookTitle.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: draft.showAuthor && author.isNotEmpty
                                      ? 4
                                      : 0,
                                ),
                                child: Text(
                                  bookTitle,
                                  key: const ValueKey<String>(
                                    'quote-card-book-title-text',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _resolveFontFamily() {
    return switch (draft.fontPreset) {
      QuoteCardFontPreset.reader => payload.readerFontFamily,
      QuoteCardFontPreset.serif => 'serif',
      QuoteCardFontPreset.sans => 'sans-serif',
    };
  }
}

class _QuoteCardBackdrop extends StatelessWidget {
  const _QuoteCardBackdrop({required this.background});

  final QuoteCardBackgroundPreset background;

  @override
  Widget build(BuildContext context) {
    final glowColor = switch (background) {
      QuoteCardBackgroundPreset.mist => const Color(0xFFFFFFFF),
      QuoteCardBackgroundPreset.paper => const Color(0xFFF8E8C8),
      QuoteCardBackgroundPreset.forest => const Color(0xFFA7BFAE),
      QuoteCardBackgroundPreset.night => const Color(0xFF68748D),
    };

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned(
          top: -90,
          right: -40,
          child: _buildGlow(
            size: 340,
            color: glowColor.withValues(alpha: 0.28),
          ),
        ),
        Positioned(
          top: 180,
          left: -80,
          child: _buildGlow(
            size: 280,
            color: glowColor.withValues(alpha: 0.14),
          ),
        ),
        Positioned(
          bottom: 220,
          right: 140,
          child: _buildGlow(
            size: 240,
            color: glowColor.withValues(alpha: 0.12),
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
                        : 0.1,
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

LinearGradient _backgroundGradient(QuoteCardBackgroundPreset background) {
  return switch (background) {
    QuoteCardBackgroundPreset.mist => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFF7F6F3), Color(0xFFECE9E2), Color(0xFFDEDBD5)],
      stops: <double>[0, 0.56, 1],
    ),
    QuoteCardBackgroundPreset.paper => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFFF8F1DF), Color(0xFFF1E7D3), Color(0xFFE7D9BC)],
    ),
    QuoteCardBackgroundPreset.forest => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFF0F3EE), Color(0xFFDDE7DD), Color(0xFFC5D2C5)],
    ),
    QuoteCardBackgroundPreset.night => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF293140), Color(0xFF171D28), Color(0xFF11151C)],
    ),
  };
}

Color _textColorForBackground(QuoteCardBackgroundPreset background) {
  return switch (background) {
    QuoteCardBackgroundPreset.night => const Color(0xFFF7F5F2),
    _ => CommonDesignTokens.textPrimary,
  };
}

double _quoteFontSize({
  required int length,
  required QuoteCardTemplate template,
}) {
  final base = switch (length) {
    <= 60 => 72.0,
    <= 120 => 62.0,
    <= 220 => 54.0,
    _ => 46.0,
  };
  return switch (template) {
    QuoteCardTemplate.spotlight => base + 4,
    QuoteCardTemplate.minimal => base - 2,
    _ => base,
  };
}

String _backgroundKey(QuoteCardBackgroundPreset background) {
  return switch (background) {
    QuoteCardBackgroundPreset.mist => 'mist',
    QuoteCardBackgroundPreset.paper => 'paper',
    QuoteCardBackgroundPreset.forest => 'forest',
    QuoteCardBackgroundPreset.night => 'night',
  };
}
