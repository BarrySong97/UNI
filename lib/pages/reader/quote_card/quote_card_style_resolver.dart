import 'package:flutter/material.dart';

import 'models/quote_card_draft.dart';

enum QuoteCardMetadataLayout { bottomLeft, bottomCenter, grid }

class QuoteCardResolvedStyle {
  const QuoteCardResolvedStyle({
    required this.family,
    required this.quoteAlignment,
    required this.quoteTextAlign,
    required this.quotePadding,
    required this.quoteMaxWidth,
    required this.quoteScale,
    required this.quoteWeight,
    required this.quoteLetterSpacing,
    required this.metadataLayout,
    required this.metadataFontSize,
    required this.metadataOpacity,
    required this.captionPanelPadding,
    required this.surfaceOverlayOpacity,
    this.imageHeightFactor,
    this.metadataBackgroundOpacity = 0,
    this.metadataBorderOpacity = 0,
    this.metadataRadius = 20,
    this.showAccentLine = false,
    this.showTopAccent = false,
    this.showBorder = false,
    this.showQuoteMark = false,
    this.quoteMarkOpacity = 0.18,
    this.quoteMarkSize = 120,
    this.showMetadataGrid = false,
  });

  final QuoteCardTemplateFamily family;
  final Alignment quoteAlignment;
  final TextAlign quoteTextAlign;
  final EdgeInsets quotePadding;
  final double quoteMaxWidth;
  final double quoteScale;
  final FontWeight quoteWeight;
  final double quoteLetterSpacing;
  final QuoteCardMetadataLayout metadataLayout;
  final double metadataFontSize;
  final double metadataOpacity;
  final EdgeInsets captionPanelPadding;
  final double surfaceOverlayOpacity;
  final double? imageHeightFactor;
  final double metadataBackgroundOpacity;
  final double metadataBorderOpacity;
  final double metadataRadius;
  final bool showAccentLine;
  final bool showTopAccent;
  final bool showBorder;
  final bool showQuoteMark;
  final double quoteMarkOpacity;
  final double quoteMarkSize;
  final bool showMetadataGrid;
}

QuoteCardResolvedStyle resolveQuoteCardStyle({required QuoteCardDraft draft}) {
  if (draft.template.family == QuoteCardTemplateFamily.gradient) {
    return _resolveGradientStyle(draft);
  }
  return _resolveImageStyle(draft);
}

QuoteCardResolvedStyle _resolveGradientStyle(QuoteCardDraft draft) {
  final layoutAlignment = switch (draft.layout) {
    QuoteCardLayoutPreset.top => const Alignment(0, -0.7),
    QuoteCardLayoutPreset.center => Alignment.center,
    QuoteCardLayoutPreset.bottom => const Alignment(0, 0.64),
  };

  return switch (draft.template) {
    QuoteCardTemplate.auroraMist => QuoteCardResolvedStyle(
      family: QuoteCardTemplateFamily.gradient,
      quoteAlignment: layoutAlignment,
      quoteTextAlign: TextAlign.center,
      quotePadding: const EdgeInsets.fromLTRB(80, 96, 80, 156),
      quoteMaxWidth: 840,
      quoteScale: 1,
      quoteWeight: FontWeight.w500,
      quoteLetterSpacing: 0,
      metadataLayout: QuoteCardMetadataLayout.bottomLeft,
      metadataFontSize: 20,
      metadataOpacity: 0.72,
      captionPanelPadding: EdgeInsets.zero,
      surfaceOverlayOpacity: 0.06,
      showQuoteMark: true,
      quoteMarkOpacity: 0.1,
      quoteMarkSize: 128,
    ),
    QuoteCardTemplate.editorialBloom => QuoteCardResolvedStyle(
      family: QuoteCardTemplateFamily.gradient,
      quoteAlignment: layoutAlignment,
      quoteTextAlign: TextAlign.left,
      quotePadding: const EdgeInsets.fromLTRB(112, 92, 78, 150),
      quoteMaxWidth: 780,
      quoteScale: 0.96,
      quoteWeight: FontWeight.w500,
      quoteLetterSpacing: 0.14,
      metadataLayout: QuoteCardMetadataLayout.bottomLeft,
      metadataFontSize: 19,
      metadataOpacity: 0.68,
      captionPanelPadding: const EdgeInsets.only(left: 2),
      surfaceOverlayOpacity: 0.08,
      showAccentLine: true,
      showTopAccent: true,
    ),
    QuoteCardTemplate.nightGlow => QuoteCardResolvedStyle(
      family: QuoteCardTemplateFamily.gradient,
      quoteAlignment: layoutAlignment,
      quoteTextAlign: TextAlign.center,
      quotePadding: const EdgeInsets.fromLTRB(96, 102, 96, 168),
      quoteMaxWidth: 790,
      quoteScale: 1.05,
      quoteWeight: FontWeight.w500,
      quoteLetterSpacing: 0.18,
      metadataLayout: QuoteCardMetadataLayout.bottomCenter,
      metadataFontSize: 19,
      metadataOpacity: 0.84,
      captionPanelPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      surfaceOverlayOpacity: 0.14,
      metadataBackgroundOpacity: 0.12,
      metadataBorderOpacity: 0.14,
      metadataRadius: 999,
      showQuoteMark: true,
      quoteMarkOpacity: 0.14,
      quoteMarkSize: 150,
    ),
    _ => throw StateError('Unsupported gradient template: ${draft.template}'),
  };
}

QuoteCardResolvedStyle _resolveImageStyle(QuoteCardDraft draft) {
  final imageHeightFactor = switch (draft.layout) {
    QuoteCardLayoutPreset.top => 0.58,
    QuoteCardLayoutPreset.center => 0.52,
    QuoteCardLayoutPreset.bottom => 0.46,
  };

  return switch (draft.template) {
    QuoteCardTemplate.coverColumn => QuoteCardResolvedStyle(
      family: QuoteCardTemplateFamily.image,
      quoteAlignment: Alignment.topLeft,
      quoteTextAlign: TextAlign.left,
      quotePadding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
      quoteMaxWidth: 760,
      quoteScale: 0.82,
      quoteWeight: FontWeight.w500,
      quoteLetterSpacing: 0.02,
      metadataLayout: QuoteCardMetadataLayout.grid,
      metadataFontSize: 13,
      metadataOpacity: 0.82,
      captionPanelPadding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      surfaceOverlayOpacity: 0.04,
      imageHeightFactor: imageHeightFactor,
      showMetadataGrid: true,
    ),
    QuoteCardTemplate.galleryFrame => QuoteCardResolvedStyle(
      family: QuoteCardTemplateFamily.image,
      quoteAlignment: Alignment.topCenter,
      quoteTextAlign: TextAlign.center,
      quotePadding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      quoteMaxWidth: 760,
      quoteScale: 0.78,
      quoteWeight: FontWeight.w500,
      quoteLetterSpacing: 0.08,
      metadataLayout: QuoteCardMetadataLayout.bottomCenter,
      metadataFontSize: 14,
      metadataOpacity: 0.78,
      captionPanelPadding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
      surfaceOverlayOpacity: 0.03,
      imageHeightFactor: imageHeightFactor,
      metadataBackgroundOpacity: 0.06,
      metadataBorderOpacity: 0.08,
      metadataRadius: 16,
    ),
    QuoteCardTemplate.archiveNote => QuoteCardResolvedStyle(
      family: QuoteCardTemplateFamily.image,
      quoteAlignment: Alignment.topLeft,
      quoteTextAlign: TextAlign.left,
      quotePadding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      quoteMaxWidth: 760,
      quoteScale: 0.8,
      quoteWeight: FontWeight.w500,
      quoteLetterSpacing: 0.04,
      metadataLayout: QuoteCardMetadataLayout.grid,
      metadataFontSize: 13,
      metadataOpacity: 0.78,
      captionPanelPadding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      surfaceOverlayOpacity: 0.05,
      imageHeightFactor: imageHeightFactor,
      showMetadataGrid: true,
      showBorder: true,
    ),
    _ => throw StateError('Unsupported image template: ${draft.template}'),
  };
}
