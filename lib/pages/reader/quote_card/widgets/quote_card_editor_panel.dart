import 'package:flutter/material.dart';

import '../../../../shared/constants/common-design-tokens.dart';
import '../models/quote_card_draft.dart';

enum QuoteCardEditorPanelMode { bottomSheet, sidePanel }

class QuoteCardEditorPanel extends StatefulWidget {
  const QuoteCardEditorPanel({
    super.key,
    required this.draft,
    this.mode = QuoteCardEditorPanelMode.bottomSheet,
    required this.onTemplateChanged,
    required this.onBackgroundChanged,
    required this.onBackgroundIntensityChanged,
    required this.onImageSourceChanged,
    required this.onLayoutChanged,
    required this.onFontPresetChanged,
    required this.onShowBookTitleChanged,
    required this.onShowAuthorChanged,
    required this.onShowChapterTitleChanged,
    required this.onShowPageLabelChanged,
    required this.onShowCollectionLabelChanged,
  });

  final QuoteCardDraft draft;
  final QuoteCardEditorPanelMode mode;
  final ValueChanged<QuoteCardTemplate> onTemplateChanged;
  final ValueChanged<QuoteCardBackgroundPreset> onBackgroundChanged;
  final ValueChanged<QuoteCardBackgroundIntensity> onBackgroundIntensityChanged;
  final ValueChanged<QuoteCardImageSource> onImageSourceChanged;
  final ValueChanged<QuoteCardLayoutPreset> onLayoutChanged;
  final ValueChanged<QuoteCardFontPreset> onFontPresetChanged;
  final ValueChanged<bool> onShowBookTitleChanged;
  final ValueChanged<bool> onShowAuthorChanged;
  final ValueChanged<bool> onShowChapterTitleChanged;
  final ValueChanged<bool> onShowPageLabelChanged;
  final ValueChanged<bool> onShowCollectionLabelChanged;

  @override
  State<QuoteCardEditorPanel> createState() => _QuoteCardEditorPanelState();
}

enum _QuoteCardEditorSection { template, background, layout, font, visibility }

class _QuoteCardEditorPanelState extends State<QuoteCardEditorPanel> {
  _QuoteCardEditorSection _section = _QuoteCardEditorSection.template;

  bool get _isSidePanel =>
      widget.mode == QuoteCardEditorPanelMode.sidePanel;

  bool get _isImageFamily =>
      widget.draft.template.family == QuoteCardTemplateFamily.image;

  @override
  Widget build(BuildContext context) {
    final isSidePanel = _isSidePanel;

    return Container(
      key: const ValueKey<String>('quote-card-editor-panel'),
      height: isSidePanel ? double.infinity : null,
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: isSidePanel
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: isSidePanel
            ? Border.all(color: CommonDesignTokens.borderColor)
            : null,
      ),
      padding: EdgeInsets.fromLTRB(16, isSidePanel ? 18 : 14, 16, 20),
      child: Column(
        mainAxisSize: isSidePanel ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!isSidePanel)
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: CommonDesignTokens.borderColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          if (!isSidePanel) const SizedBox(height: 14),
          if (isSidePanel)
            const Text(
              'Customize',
              style: TextStyle(
                color: CommonDesignTokens.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (isSidePanel) const SizedBox(height: 12),
          if (isSidePanel)
            Expanded(child: _buildOptions())
          else
            SizedBox(height: 196, child: _buildOptions()),
          const SizedBox(height: 16),
          Row(
            children: _QuoteCardEditorSection.values
                .map((section) => Expanded(child: _buildTab(section)))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (_section) {
        _QuoteCardEditorSection.template => _buildTemplateOptions(),
        _QuoteCardEditorSection.background => _buildBackgroundOptions(),
        _QuoteCardEditorSection.layout => _buildLayoutOptions(),
        _QuoteCardEditorSection.font => _buildFontOptions(),
        _QuoteCardEditorSection.visibility => _buildVisibilityOptions(),
      },
    );
  }

  Widget _buildTemplateOptions() {
    return _buildSingleRowOptions<QuoteCardTemplate>(
      keyName: 'template',
      values: QuoteCardTemplate.values,
      selectedValue: widget.draft.template,
      labelOf: _templateLabel,
      onTap: widget.onTemplateChanged,
      helperOf: (value) => value.family == QuoteCardTemplateFamily.gradient
          ? 'Gradient'
          : 'Image',
      previewBuilder: (value, selected) => _TemplateOptionPreview(
        key: ValueKey<String>(
          'quote-card-template-preview-${_keyLabel(_templateLabel(value))}',
        ),
        template: value,
        selected: selected,
        compact: !_isSidePanel,
      ),
    );
  }

  Widget _buildBackgroundOptions() {
    if (_isImageFamily) {
      return _AdaptiveOptionsColumn(
        key: const ValueKey<String>('quote-card-options-background'),
        titleOne: 'Tone',
        contentOne: _buildSingleRowOptions<QuoteCardBackgroundPreset>(
          keyName: 'background',
          values: const <QuoteCardBackgroundPreset>[
            QuoteCardBackgroundPreset.mist,
            QuoteCardBackgroundPreset.bloom,
            QuoteCardBackgroundPreset.archivePaper,
            QuoteCardBackgroundPreset.night,
          ],
          selectedValue: widget.draft.background,
          labelOf: _imageBackgroundLabel,
          onTap: widget.onBackgroundChanged,
          swatchColor: _backgroundSwatch,
        ),
      titleTwo: 'Image',
      contentTwo: _buildSingleRowOptions<QuoteCardImageSource>(
          keyName: 'image-source',
          values: QuoteCardImageSource.values,
          selectedValue: widget.draft.imageSource,
          labelOf: _imageSourceLabel,
          onTap: widget.onImageSourceChanged,
        iconOf: _imageSourceIcon,
      ),
      useFlexibleRows: !_isSidePanel,
    );
  }

    return _AdaptiveOptionsColumn(
      key: const ValueKey<String>('quote-card-options-background'),
      titleOne: 'Palette',
      contentOne: _buildSingleRowOptions<QuoteCardBackgroundPreset>(
        keyName: 'background',
        values: QuoteCardBackgroundPreset.values,
        selectedValue: widget.draft.background,
        labelOf: _backgroundLabel,
        onTap: widget.onBackgroundChanged,
        swatchColor: _backgroundSwatch,
      ),
      titleTwo: 'Intensity',
      contentTwo: _buildSingleRowOptions<QuoteCardBackgroundIntensity>(
        keyName: 'background-intensity',
        values: QuoteCardBackgroundIntensity.values,
        selectedValue: widget.draft.backgroundIntensity,
        labelOf: _backgroundIntensityLabel,
        onTap: widget.onBackgroundIntensityChanged,
        iconOf: _backgroundIntensityIcon,
      ),
      useFlexibleRows: !_isSidePanel,
    );
  }

  Widget _buildLayoutOptions() {
    return _buildSingleRowOptions<QuoteCardLayoutPreset>(
      keyName: 'layout',
      values: QuoteCardLayoutPreset.values,
      selectedValue: widget.draft.layout,
      labelOf: (value) => _isImageFamily
          ? _imageLayoutLabel(value)
          : _gradientLayoutLabel(value),
      onTap: widget.onLayoutChanged,
      iconOf: (value) => _layoutIcon(value, isImageFamily: _isImageFamily),
    );
  }

  Widget _buildFontOptions() {
    return _buildSingleRowOptions<QuoteCardFontPreset>(
      keyName: 'font',
      values: QuoteCardFontPreset.values,
      selectedValue: widget.draft.fontPreset,
      labelOf: _fontLabel,
      onTap: widget.onFontPresetChanged,
      iconOf: _fontIcon,
    );
  }

  Widget _buildVisibilityOptions() {
    final tiles = <Widget>[
      _VisibilityTile(
        key: const ValueKey<String>('quote-card-visibility-book-title'),
        label: 'Book Title',
        value: widget.draft.showBookTitle,
        onChanged: widget.onShowBookTitleChanged,
      ),
      _VisibilityTile(
        key: const ValueKey<String>('quote-card-visibility-author'),
        label: 'Author',
        value: widget.draft.showAuthor,
        onChanged: widget.onShowAuthorChanged,
      ),
      _VisibilityTile(
        key: const ValueKey<String>('quote-card-visibility-chapter'),
        label: 'Chapter',
        value: widget.draft.showChapterTitle,
        onChanged: widget.onShowChapterTitleChanged,
      ),
      _VisibilityTile(
        key: const ValueKey<String>('quote-card-visibility-page'),
        label: 'Page',
        value: widget.draft.showPageLabel,
        onChanged: widget.onShowPageLabelChanged,
      ),
      if (_isImageFamily)
        _VisibilityTile(
          key: const ValueKey<String>('quote-card-visibility-collection'),
          label: 'Collection',
          value: widget.draft.showCollectionLabel,
          onChanged: widget.onShowCollectionLabelChanged,
        ),
    ];

    return SingleChildScrollView(
      key: const ValueKey<String>('quote-card-options-visibility'),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: tiles
            .map((tile) => SizedBox(width: 170, child: tile))
            .toList(growable: false),
      ),
    );
  }

  Widget _buildTab(_QuoteCardEditorSection section) {
    final isSelected = _section == section;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        key: ValueKey<String>('quote-card-tab-${_sectionKey(section)}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _section = section),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _sectionLabel(section),
                style: TextStyle(
                  color: isSelected
                      ? CommonDesignTokens.textPrimary
                      : CommonDesignTokens.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2,
                width: 24,
                decoration: BoxDecoration(
                  color: isSelected
                      ? CommonDesignTokens.headerLabelColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleRowOptions<T>({
    required String keyName,
    required List<T> values,
    required T selectedValue,
    required String Function(T value) labelOf,
    required ValueChanged<T> onTap,
    IconData Function(T value)? iconOf,
    String Function(T value)? helperOf,
    Color Function(T value)? swatchColor,
    Widget Function(T value, bool selected)? previewBuilder,
  }) {
    final isPreviewRow = previewBuilder != null;
    final useRectTile = isPreviewRow;
    final cardWidth = _isSidePanel
        ? isPreviewRow
              ? 108.0
              : 118.0
        : 108.0;
    final listHeight = _isSidePanel
        ? isPreviewRow
              ? null
              : 128.0
        : null;

    final listView = ListView.separated(
      key: ValueKey<String>('quote-card-options-$keyName'),
      scrollDirection: Axis.horizontal,
      itemCount: values.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final value = values[index];
        final selected = value == selectedValue;
        final label = labelOf(value);
        return InkWell(
          key: ValueKey<String>(
            'quote-card-option-$keyName-${_keyLabel(label)}',
          ),
          borderRadius: useRectTile ? BorderRadius.zero : BorderRadius.circular(16),
          onTap: () => onTap(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: cardWidth,
            padding: EdgeInsets.all(_isSidePanel ? 4 : 10),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFF7F3EE)
                  : CommonDesignTokens.pageBackground,
              borderRadius: useRectTile ? BorderRadius.zero : BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? CommonDesignTokens.headerLabelColor
                    : CommonDesignTokens.borderColor,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (previewBuilder != null)
                  if (_isSidePanel)
                    Expanded(child: previewBuilder(value, selected))
                  else
                    previewBuilder(value, selected)
                else if (swatchColor != null)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: swatchColor(value),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      border: Border.all(color: CommonDesignTokens.borderColor),
                    ),
                    child: Icon(
                      iconOf?.call(value) ?? Icons.tune,
                      color: CommonDesignTokens.textPrimary,
                      size: 14,
                    ),
                  ),
                if (previewBuilder != null && _isSidePanel)
                  const SizedBox(height: 6)
                else
                  const Spacer(),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CommonDesignTokens.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (helperOf != null) ...<Widget>[
                  const SizedBox(height: 1),
                  Text(
                    helperOf(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CommonDesignTokens.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (listHeight == null) {
      return listView;
    }

    return SizedBox(height: listHeight, child: listView);
  }
}

class _AdaptiveOptionsColumn extends StatelessWidget {
  const _AdaptiveOptionsColumn({
    super.key,
    required this.titleOne,
    required this.contentOne,
    required this.titleTwo,
    required this.contentTwo,
    this.useFlexibleRows = true,
  });

  final String titleOne;
  final Widget contentOne;
  final String titleTwo;
  final Widget contentTwo;
  final bool useFlexibleRows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeading(title: titleOne),
        const SizedBox(height: 8),
        if (useFlexibleRows) Expanded(child: contentOne) else contentOne,
        const SizedBox(height: 12),
        _SectionHeading(title: titleTwo),
        const SizedBox(height: 8),
        if (useFlexibleRows) Expanded(child: contentTwo) else contentTwo,
      ],
    );
  }
}

class _TemplateOptionPreview extends StatelessWidget {
  const _TemplateOptionPreview({
    super.key,
    required this.template,
    required this.selected,
    required this.compact,
  });

  final QuoteCardTemplate template;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? CommonDesignTokens.headerLabelColor.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.55);
    final previewKey = ValueKey<String>(
      'quote-card-template-preview-body-${_keyLabel(_templateLabel(template))}',
    );
    final quoteColor = switch (template) {
      QuoteCardTemplate.nightGlow => Colors.white,
      _ => const Color(0xFF392F27),
    };

    final previewChild = Container(
      key: previewKey,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        gradient: _templatePreviewGradient(template),
        color: _templatePreviewGradient(template) == null
            ? _templatePreviewColor(template)
            : null,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          ..._templatePreviewAccents(template),
          Positioned(
            top: compact ? 8 : 12,
            left: compact ? 8 : 10,
            child: Text(
              '“',
              style: TextStyle(
                color: quoteColor.withValues(alpha: 0.82),
                fontSize: compact ? 16 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            left: compact ? 8 : 10,
            right: compact ? 8 : 10,
            top: compact ? 42 : 86,
            child: Column(
              children: <Widget>[
                _MiniLine(widthFactor: 0.92, color: quoteColor),
                SizedBox(height: compact ? 5 : 8),
                _MiniLine(widthFactor: 0.74, color: quoteColor),
              ],
            ),
          ),
          Positioned(
            left: compact ? 8 : 10,
            right: compact ? 18 : 24,
            bottom: compact ? 10 : 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MiniLine(
                  widthFactor: 0.52,
                  color: quoteColor.withValues(alpha: 0.72),
                  thickness: 2,
                ),
                SizedBox(height: compact ? 4 : 6),
                _MiniLine(
                  widthFactor: 0.38,
                  color: quoteColor.withValues(alpha: 0.58),
                  thickness: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!compact) {
      return SizedBox.expand(child: previewChild);
    }

    return Center(
      child: SizedBox(
        width: 56,
        child: AspectRatio(
          aspectRatio: 0.62,
          child: previewChild,
        ),
      ),
    );
  }
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({
    required this.widthFactor,
    required this.color,
    this.thickness = 3,
  });

  final double widthFactor;
  final Color color;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: thickness,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(thickness),
        ),
      ),
    );
  }
}

LinearGradient? _templatePreviewGradient(QuoteCardTemplate template) {
  return switch (template) {
    QuoteCardTemplate.auroraMist => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFF7EDE2), Color(0xFFE8F2F1), Color(0xFFE6E1F4)],
    ),
    QuoteCardTemplate.editorialBloom => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFFF4ECE3), Color(0xFFE7DDD1)],
    ),
    QuoteCardTemplate.nightGlow => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF2B2140), Color(0xFF111A2E), Color(0xFF0B1020)],
    ),
    _ => null,
  };
}

Color _templatePreviewColor(QuoteCardTemplate template) {
  return switch (template) {
    QuoteCardTemplate.coverColumn => const Color(0xFFF1ECE4),
    QuoteCardTemplate.galleryFrame => const Color(0xFFE8E5DF),
    QuoteCardTemplate.archiveNote => const Color(0xFFF4EDDD),
    _ => Colors.transparent,
  };
}

List<Widget> _templatePreviewAccents(QuoteCardTemplate template) {
  switch (template) {
    case QuoteCardTemplate.coverColumn:
      return <Widget>[
        Positioned(
          top: 8,
          bottom: 8,
          left: 8,
          width: 20,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFFCEC3B2), Color(0xFFB59F86)],
              ),
            ),
          ),
        ),
      ];
    case QuoteCardTemplate.galleryFrame:
      return <Widget>[
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.45),
              border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
            ),
          ),
        ),
      ];
    case QuoteCardTemplate.archiveNote:
      return <Widget>[
        Positioned(
          top: 10,
          left: 16,
          right: 16,
          height: 8,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0xFFB99E74).withValues(alpha: 0.45),
            ),
          ),
        ),
      ];
    default:
      return const <Widget>[];
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: CommonDesignTokens.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _VisibilityTile extends StatelessWidget {
  const _VisibilityTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CommonDesignTokens.pageBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CommonDesignTokens.borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: CommonDesignTokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: CommonDesignTokens.headerLabelColor,
            activeTrackColor: CommonDesignTokens.headerLabelColor.withValues(
              alpha: 0.35,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

String _sectionLabel(_QuoteCardEditorSection section) {
  return switch (section) {
    _QuoteCardEditorSection.template => 'Template',
    _QuoteCardEditorSection.background => 'Background',
    _QuoteCardEditorSection.layout => 'Layout',
    _QuoteCardEditorSection.font => 'Font',
    _QuoteCardEditorSection.visibility => 'Visibility',
  };
}

String _templateLabel(QuoteCardTemplate value) {
  return switch (value) {
    QuoteCardTemplate.auroraMist => 'Aurora',
    QuoteCardTemplate.editorialBloom => 'Editorial',
    QuoteCardTemplate.nightGlow => 'Night Glow',
    QuoteCardTemplate.coverColumn => 'Cover',
    QuoteCardTemplate.galleryFrame => 'Gallery',
    QuoteCardTemplate.archiveNote => 'Archive',
  };
}

String _backgroundLabel(QuoteCardBackgroundPreset value) {
  return switch (value) {
    QuoteCardBackgroundPreset.mist => 'Mist',
    QuoteCardBackgroundPreset.bloom => 'Bloom',
    QuoteCardBackgroundPreset.forest => 'Forest',
    QuoteCardBackgroundPreset.sunset => 'Sunset',
    QuoteCardBackgroundPreset.night => 'Night',
    QuoteCardBackgroundPreset.archivePaper => 'Archive',
  };
}

String _imageBackgroundLabel(QuoteCardBackgroundPreset value) {
  return switch (value) {
    QuoteCardBackgroundPreset.mist => 'Mist',
    QuoteCardBackgroundPreset.bloom => 'Paper',
    QuoteCardBackgroundPreset.archivePaper => 'Archive',
    QuoteCardBackgroundPreset.night => 'Night',
    _ => _backgroundLabel(value),
  };
}

String _gradientLayoutLabel(QuoteCardLayoutPreset value) {
  return switch (value) {
    QuoteCardLayoutPreset.top => 'Top',
    QuoteCardLayoutPreset.center => 'Center',
    QuoteCardLayoutPreset.bottom => 'Bottom',
  };
}

String _imageLayoutLabel(QuoteCardLayoutPreset value) {
  return switch (value) {
    QuoteCardLayoutPreset.top => 'Image Focus',
    QuoteCardLayoutPreset.center => 'Balanced',
    QuoteCardLayoutPreset.bottom => 'Text Focus',
  };
}

String _fontLabel(QuoteCardFontPreset value) {
  return switch (value) {
    QuoteCardFontPreset.reader => 'Reader',
    QuoteCardFontPreset.serif => 'Serif',
    QuoteCardFontPreset.sans => 'Sans',
    QuoteCardFontPreset.displaySerif => 'Display',
  };
}

String _imageSourceLabel(QuoteCardImageSource value) {
  return switch (value) {
    QuoteCardImageSource.bookCover => 'Cover',
    QuoteCardImageSource.artworkStillLife => 'Still Life',
    QuoteCardImageSource.artworkAbstract => 'Abstract',
    QuoteCardImageSource.artworkBotanical => 'Botanical',
  };
}

String _backgroundIntensityLabel(QuoteCardBackgroundIntensity value) {
  return switch (value) {
    QuoteCardBackgroundIntensity.subtle => 'Subtle',
    QuoteCardBackgroundIntensity.medium => 'Medium',
    QuoteCardBackgroundIntensity.strong => 'Strong',
  };
}

Color _backgroundSwatch(QuoteCardBackgroundPreset value) {
  return switch (value) {
    QuoteCardBackgroundPreset.mist => const Color(0xFFE7E4DD),
    QuoteCardBackgroundPreset.bloom => const Color(0xFFE3C1B4),
    QuoteCardBackgroundPreset.forest => const Color(0xFFBCD0C0),
    QuoteCardBackgroundPreset.sunset => const Color(0xFFE1B9A6),
    QuoteCardBackgroundPreset.night => const Color(0xFF1E2431),
    QuoteCardBackgroundPreset.archivePaper => const Color(0xFFD3C6B3),
  };
}

IconData _layoutIcon(
  QuoteCardLayoutPreset value, {
  required bool isImageFamily,
}) {
  if (isImageFamily) {
    return switch (value) {
      QuoteCardLayoutPreset.top => Icons.image_outlined,
      QuoteCardLayoutPreset.center => Icons.dashboard_customize_outlined,
      QuoteCardLayoutPreset.bottom => Icons.subject_outlined,
    };
  }
  return switch (value) {
    QuoteCardLayoutPreset.top => Icons.vertical_align_top,
    QuoteCardLayoutPreset.center => Icons.vertical_align_center,
    QuoteCardLayoutPreset.bottom => Icons.vertical_align_bottom,
  };
}

IconData _fontIcon(QuoteCardFontPreset value) {
  return switch (value) {
    QuoteCardFontPreset.reader => Icons.menu_book_outlined,
    QuoteCardFontPreset.serif => Icons.format_size,
    QuoteCardFontPreset.sans => Icons.text_fields,
    QuoteCardFontPreset.displaySerif => Icons.draw_outlined,
  };
}

IconData _imageSourceIcon(QuoteCardImageSource value) {
  return switch (value) {
    QuoteCardImageSource.bookCover => Icons.menu_book_outlined,
    QuoteCardImageSource.artworkStillLife => Icons.local_florist_outlined,
    QuoteCardImageSource.artworkAbstract => Icons.blur_circular_outlined,
    QuoteCardImageSource.artworkBotanical => Icons.park_outlined,
  };
}

IconData _backgroundIntensityIcon(QuoteCardBackgroundIntensity value) {
  return switch (value) {
    QuoteCardBackgroundIntensity.subtle => Icons.water_drop_outlined,
    QuoteCardBackgroundIntensity.medium => Icons.lens_blur_outlined,
    QuoteCardBackgroundIntensity.strong => Icons.brightness_high_outlined,
  };
}

String _keyLabel(String value) {
  return value.toLowerCase().replaceAll(' ', '-');
}

String _sectionKey(_QuoteCardEditorSection section) {
  return switch (section) {
    _QuoteCardEditorSection.template => 'template',
    _QuoteCardEditorSection.background => 'background',
    _QuoteCardEditorSection.layout => 'layout',
    _QuoteCardEditorSection.font => 'font',
    _QuoteCardEditorSection.visibility => 'visibility',
  };
}
