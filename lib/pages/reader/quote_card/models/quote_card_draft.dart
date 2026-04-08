enum QuoteCardTemplate { classic, spotlight, editorial, minimal }

enum QuoteCardBackgroundPreset { mist, paper, forest, night }

enum QuoteCardLayoutPreset { top, center, bottom }

enum QuoteCardFontPreset { reader, serif, sans }

class QuoteCardDraft {
  const QuoteCardDraft({
    this.template = QuoteCardTemplate.classic,
    this.background = QuoteCardBackgroundPreset.mist,
    this.layout = QuoteCardLayoutPreset.center,
    this.fontPreset = QuoteCardFontPreset.reader,
    this.showBookTitle = true,
    this.showAuthor = true,
    this.isControlsCollapsed = false,
  });

  final QuoteCardTemplate template;
  final QuoteCardBackgroundPreset background;
  final QuoteCardLayoutPreset layout;
  final QuoteCardFontPreset fontPreset;
  final bool showBookTitle;
  final bool showAuthor;
  final bool isControlsCollapsed;

  QuoteCardDraft copyWith({
    QuoteCardTemplate? template,
    QuoteCardBackgroundPreset? background,
    QuoteCardLayoutPreset? layout,
    QuoteCardFontPreset? fontPreset,
    bool? showBookTitle,
    bool? showAuthor,
    bool? isControlsCollapsed,
  }) {
    return QuoteCardDraft(
      template: template ?? this.template,
      background: background ?? this.background,
      layout: layout ?? this.layout,
      fontPreset: fontPreset ?? this.fontPreset,
      showBookTitle: showBookTitle ?? this.showBookTitle,
      showAuthor: showAuthor ?? this.showAuthor,
      isControlsCollapsed: isControlsCollapsed ?? this.isControlsCollapsed,
    );
  }
}
