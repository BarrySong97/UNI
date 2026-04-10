enum QuoteCardTemplate {
  auroraMist,
  editorialBloom,
  nightGlow,
  coverColumn,
  galleryFrame,
  archiveNote,
}

enum QuoteCardTemplateFamily { gradient, image }

enum QuoteCardBackgroundPreset {
  mist,
  bloom,
  forest,
  sunset,
  night,
  archivePaper,
}

enum QuoteCardLayoutPreset { top, center, bottom }

enum QuoteCardFontPreset { reader, serif, sans, displaySerif }

enum QuoteCardImageSource {
  bookCover,
  artworkStillLife,
  artworkAbstract,
  artworkBotanical,
}

enum QuoteCardBackgroundIntensity { subtle, medium, strong }

extension QuoteCardTemplateX on QuoteCardTemplate {
  QuoteCardTemplateFamily get family {
    return switch (this) {
      QuoteCardTemplate.auroraMist ||
      QuoteCardTemplate.editorialBloom ||
      QuoteCardTemplate.nightGlow => QuoteCardTemplateFamily.gradient,
      QuoteCardTemplate.coverColumn ||
      QuoteCardTemplate.galleryFrame ||
      QuoteCardTemplate.archiveNote => QuoteCardTemplateFamily.image,
    };
  }

  QuoteCardBackgroundPreset get defaultBackground {
    return switch (this) {
      QuoteCardTemplate.auroraMist => QuoteCardBackgroundPreset.mist,
      QuoteCardTemplate.editorialBloom => QuoteCardBackgroundPreset.bloom,
      QuoteCardTemplate.nightGlow => QuoteCardBackgroundPreset.night,
      QuoteCardTemplate.coverColumn => QuoteCardBackgroundPreset.archivePaper,
      QuoteCardTemplate.galleryFrame => QuoteCardBackgroundPreset.mist,
      QuoteCardTemplate.archiveNote => QuoteCardBackgroundPreset.archivePaper,
    };
  }

  QuoteCardLayoutPreset get defaultLayout {
    return switch (this) {
      QuoteCardTemplate.auroraMist => QuoteCardLayoutPreset.center,
      QuoteCardTemplate.editorialBloom => QuoteCardLayoutPreset.top,
      QuoteCardTemplate.nightGlow => QuoteCardLayoutPreset.center,
      QuoteCardTemplate.coverColumn => QuoteCardLayoutPreset.center,
      QuoteCardTemplate.galleryFrame => QuoteCardLayoutPreset.top,
      QuoteCardTemplate.archiveNote => QuoteCardLayoutPreset.center,
    };
  }

  QuoteCardFontPreset get defaultFontPreset {
    return switch (this) {
      QuoteCardTemplate.auroraMist => QuoteCardFontPreset.reader,
      QuoteCardTemplate.editorialBloom => QuoteCardFontPreset.serif,
      QuoteCardTemplate.nightGlow => QuoteCardFontPreset.displaySerif,
      QuoteCardTemplate.coverColumn => QuoteCardFontPreset.serif,
      QuoteCardTemplate.galleryFrame => QuoteCardFontPreset.displaySerif,
      QuoteCardTemplate.archiveNote => QuoteCardFontPreset.serif,
    };
  }

  QuoteCardImageSource get defaultImageSource {
    return switch (this) {
      QuoteCardTemplate.galleryFrame => QuoteCardImageSource.artworkStillLife,
      QuoteCardTemplate.archiveNote => QuoteCardImageSource.artworkBotanical,
      _ => QuoteCardImageSource.bookCover,
    };
  }

  bool get defaultShowBookTitle => true;
  bool get defaultShowAuthor => true;
  bool get defaultShowChapterTitle => family == QuoteCardTemplateFamily.image;
  bool get defaultShowPageLabel {
    return switch (this) {
      QuoteCardTemplate.galleryFrame => false,
      QuoteCardTemplate.coverColumn || QuoteCardTemplate.archiveNote => true,
      _ => false,
    };
  }

  bool get defaultShowCollectionLabel => false;
}

class QuoteCardDraft {
  const QuoteCardDraft({
    this.template = QuoteCardTemplate.auroraMist,
    this.background = QuoteCardBackgroundPreset.mist,
    this.layout = QuoteCardLayoutPreset.center,
    this.fontPreset = QuoteCardFontPreset.reader,
    this.imageSource = QuoteCardImageSource.bookCover,
    this.backgroundIntensity = QuoteCardBackgroundIntensity.medium,
    this.showBookTitle = true,
    this.showAuthor = true,
    this.showChapterTitle = true,
    this.showPageLabel = true,
    this.showCollectionLabel = false,
    this.isControlsCollapsed = false,
  });

  final QuoteCardTemplate template;
  final QuoteCardBackgroundPreset background;
  final QuoteCardLayoutPreset layout;
  final QuoteCardFontPreset fontPreset;
  final QuoteCardImageSource imageSource;
  final QuoteCardBackgroundIntensity backgroundIntensity;
  final bool showBookTitle;
  final bool showAuthor;
  final bool showChapterTitle;
  final bool showPageLabel;
  final bool showCollectionLabel;
  final bool isControlsCollapsed;

  QuoteCardDraft copyWith({
    QuoteCardTemplate? template,
    QuoteCardBackgroundPreset? background,
    QuoteCardLayoutPreset? layout,
    QuoteCardFontPreset? fontPreset,
    QuoteCardImageSource? imageSource,
    QuoteCardBackgroundIntensity? backgroundIntensity,
    bool? showBookTitle,
    bool? showAuthor,
    bool? showChapterTitle,
    bool? showPageLabel,
    bool? showCollectionLabel,
    bool? isControlsCollapsed,
  }) {
    return QuoteCardDraft(
      template: template ?? this.template,
      background: background ?? this.background,
      layout: layout ?? this.layout,
      fontPreset: fontPreset ?? this.fontPreset,
      imageSource: imageSource ?? this.imageSource,
      backgroundIntensity: backgroundIntensity ?? this.backgroundIntensity,
      showBookTitle: showBookTitle ?? this.showBookTitle,
      showAuthor: showAuthor ?? this.showAuthor,
      showChapterTitle: showChapterTitle ?? this.showChapterTitle,
      showPageLabel: showPageLabel ?? this.showPageLabel,
      showCollectionLabel: showCollectionLabel ?? this.showCollectionLabel,
      isControlsCollapsed: isControlsCollapsed ?? this.isControlsCollapsed,
    );
  }

  QuoteCardDraft applyTemplateDefaults(QuoteCardTemplate nextTemplate) {
    return copyWith(
      template: nextTemplate,
      background: nextTemplate.defaultBackground,
      layout: nextTemplate.defaultLayout,
      fontPreset: nextTemplate.defaultFontPreset,
      imageSource: nextTemplate.defaultImageSource,
      backgroundIntensity: QuoteCardBackgroundIntensity.medium,
      showBookTitle: nextTemplate.defaultShowBookTitle,
      showAuthor: nextTemplate.defaultShowAuthor,
      showChapterTitle: nextTemplate.defaultShowChapterTitle,
      showPageLabel: nextTemplate.defaultShowPageLabel,
      showCollectionLabel: nextTemplate.defaultShowCollectionLabel,
    );
  }
}
