import 'package:flutter/material.dart';

import 'models/quote_card_draft.dart';

class QuoteCardResolvedStyle {
  const QuoteCardResolvedStyle({
    required this.quoteAlignment,
    required this.quoteTextAlign,
    required this.quotePadding,
    required this.metadataOpacity,
    required this.metadataFontSize,
    this.showVerticalAccent = false,
    this.showTopAccent = false,
    this.showBorder = false,
  });

  final Alignment quoteAlignment;
  final TextAlign quoteTextAlign;
  final EdgeInsets quotePadding;
  final double metadataOpacity;
  final double metadataFontSize;
  final bool showVerticalAccent;
  final bool showTopAccent;
  final bool showBorder;
}

QuoteCardResolvedStyle resolveQuoteCardStyle({required QuoteCardDraft draft}) {
  final layoutAlignment = switch (draft.layout) {
    QuoteCardLayoutPreset.top => const Alignment(0, -0.68),
    QuoteCardLayoutPreset.center => Alignment.center,
    QuoteCardLayoutPreset.bottom => const Alignment(0, 0.62),
  };

  return switch (draft.template) {
    QuoteCardTemplate.classic => QuoteCardResolvedStyle(
      quoteAlignment: layoutAlignment,
      quoteTextAlign: TextAlign.left,
      quotePadding: const EdgeInsets.fromLTRB(68, 76, 68, 132),
      metadataOpacity: 0.72,
      metadataFontSize: 22,
    ),
    QuoteCardTemplate.spotlight => QuoteCardResolvedStyle(
      quoteAlignment: layoutAlignment,
      quoteTextAlign: TextAlign.center,
      quotePadding: const EdgeInsets.fromLTRB(76, 88, 76, 142),
      metadataOpacity: 0.76,
      metadataFontSize: 22,
    ),
    QuoteCardTemplate.editorial => QuoteCardResolvedStyle(
      quoteAlignment: layoutAlignment,
      quoteTextAlign: TextAlign.left,
      quotePadding: const EdgeInsets.fromLTRB(96, 82, 68, 132),
      metadataOpacity: 0.7,
      metadataFontSize: 21,
      showVerticalAccent: true,
      showTopAccent: true,
    ),
    QuoteCardTemplate.minimal => QuoteCardResolvedStyle(
      quoteAlignment: layoutAlignment,
      quoteTextAlign: TextAlign.left,
      quotePadding: const EdgeInsets.fromLTRB(82, 104, 82, 156),
      metadataOpacity: 0.52,
      metadataFontSize: 19,
      showBorder: true,
    ),
  };
}
