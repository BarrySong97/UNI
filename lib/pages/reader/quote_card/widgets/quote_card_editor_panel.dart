import 'package:flutter/material.dart';

import '../../../../shared/constants/common-design-tokens.dart';
import '../models/quote_card_draft.dart';

class QuoteCardEditorPanel extends StatefulWidget {
  const QuoteCardEditorPanel({
    super.key,
    required this.draft,
    required this.onTemplateChanged,
    required this.onBackgroundChanged,
    required this.onLayoutChanged,
    required this.onFontPresetChanged,
    required this.onShowBookTitleChanged,
    required this.onShowAuthorChanged,
  });

  final QuoteCardDraft draft;
  final ValueChanged<QuoteCardTemplate> onTemplateChanged;
  final ValueChanged<QuoteCardBackgroundPreset> onBackgroundChanged;
  final ValueChanged<QuoteCardLayoutPreset> onLayoutChanged;
  final ValueChanged<QuoteCardFontPreset> onFontPresetChanged;
  final ValueChanged<bool> onShowBookTitleChanged;
  final ValueChanged<bool> onShowAuthorChanged;

  @override
  State<QuoteCardEditorPanel> createState() => _QuoteCardEditorPanelState();
}

enum _QuoteCardEditorSection { template, background, layout, font, visibility }

class _QuoteCardEditorPanelState extends State<QuoteCardEditorPanel> {
  _QuoteCardEditorSection _section = _QuoteCardEditorSection.template;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('quote-card-editor-panel'),
      decoration: const BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: CommonDesignTokens.borderColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(height: 120, child: _buildOptions()),
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
        _QuoteCardEditorSection.template => _buildChipList<QuoteCardTemplate>(
          keyName: 'template',
          values: QuoteCardTemplate.values,
          isSelected: (value) => widget.draft.template == value,
          labelOf: _templateLabel,
          onTap: widget.onTemplateChanged,
        ),
        _QuoteCardEditorSection.background =>
          _buildChipList<QuoteCardBackgroundPreset>(
            keyName: 'background',
            values: QuoteCardBackgroundPreset.values,
            isSelected: (value) => widget.draft.background == value,
            labelOf: _backgroundLabel,
            onTap: widget.onBackgroundChanged,
            swatchColor: _backgroundSwatch,
          ),
        _QuoteCardEditorSection.layout => _buildChipList<QuoteCardLayoutPreset>(
          keyName: 'layout',
          values: QuoteCardLayoutPreset.values,
          isSelected: (value) => widget.draft.layout == value,
          labelOf: _layoutLabel,
          onTap: widget.onLayoutChanged,
        ),
        _QuoteCardEditorSection.font => _buildChipList<QuoteCardFontPreset>(
          keyName: 'font',
          values: QuoteCardFontPreset.values,
          isSelected: (value) => widget.draft.fontPreset == value,
          labelOf: _fontLabel,
          onTap: widget.onFontPresetChanged,
        ),
        _QuoteCardEditorSection.visibility => _buildVisibilityOptions(),
      },
    );
  }

  Widget _buildVisibilityOptions() {
    return Row(
      key: const ValueKey<String>('quote-card-options-visibility'),
      children: <Widget>[
        Expanded(
          child: _VisibilityTile(
            key: const ValueKey<String>('quote-card-visibility-book-title'),
            label: 'Book Title',
            value: widget.draft.showBookTitle,
            onChanged: widget.onShowBookTitleChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _VisibilityTile(
            key: const ValueKey<String>('quote-card-visibility-author'),
            label: 'Author',
            value: widget.draft.showAuthor,
            onChanged: widget.onShowAuthorChanged,
          ),
        ),
      ],
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

  Widget _buildChipList<T>({
    required String keyName,
    required List<T> values,
    required bool Function(T value) isSelected,
    required String Function(T value) labelOf,
    required ValueChanged<T> onTap,
    Color Function(T value)? swatchColor,
  }) {
    return ListView.separated(
      key: ValueKey<String>('quote-card-options-$keyName'),
      scrollDirection: Axis.horizontal,
      itemCount: values.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final value = values[index];
        final selected = isSelected(value);
        return InkWell(
          key: ValueKey<String>(
            'quote-card-option-$keyName-${_keyLabel(labelOf(value))}',
          ),
          borderRadius: BorderRadius.circular(14),
          onTap: () => onTap(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 108,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFF7F3EE)
                  : CommonDesignTokens.pageBackground,
              borderRadius: BorderRadius.circular(14),
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
                if (swatchColor != null)
                  Container(
                    width: 28,
                    height: 28,
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
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      border: Border.all(color: CommonDesignTokens.borderColor),
                    ),
                    child: Icon(
                      _iconForValue(value),
                      color: CommonDesignTokens.textPrimary,
                      size: 16,
                    ),
                  ),
                const Spacer(),
                Text(
                  labelOf(value),
                  style: const TextStyle(
                    color: CommonDesignTokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconForValue(Object? value) {
    return switch (value) {
      QuoteCardTemplate.classic => Icons.article_outlined,
      QuoteCardTemplate.spotlight => Icons.light_mode_outlined,
      QuoteCardTemplate.editorial => Icons.view_sidebar_outlined,
      QuoteCardTemplate.minimal => Icons.crop_square_outlined,
      QuoteCardLayoutPreset.top => Icons.vertical_align_top,
      QuoteCardLayoutPreset.center => Icons.vertical_align_center,
      QuoteCardLayoutPreset.bottom => Icons.vertical_align_bottom,
      QuoteCardFontPreset.reader => Icons.menu_book_outlined,
      QuoteCardFontPreset.serif => Icons.format_size,
      QuoteCardFontPreset.sans => Icons.text_fields,
      _ => Icons.tune,
    };
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
    QuoteCardTemplate.classic => 'Classic',
    QuoteCardTemplate.spotlight => 'Spotlight',
    QuoteCardTemplate.editorial => 'Editorial',
    QuoteCardTemplate.minimal => 'Minimal',
  };
}

String _backgroundLabel(QuoteCardBackgroundPreset value) {
  return switch (value) {
    QuoteCardBackgroundPreset.mist => 'Mist',
    QuoteCardBackgroundPreset.paper => 'Paper',
    QuoteCardBackgroundPreset.forest => 'Forest',
    QuoteCardBackgroundPreset.night => 'Night',
  };
}

String _layoutLabel(QuoteCardLayoutPreset value) {
  return switch (value) {
    QuoteCardLayoutPreset.top => 'Top',
    QuoteCardLayoutPreset.center => 'Center',
    QuoteCardLayoutPreset.bottom => 'Bottom',
  };
}

String _fontLabel(QuoteCardFontPreset value) {
  return switch (value) {
    QuoteCardFontPreset.reader => 'Reader',
    QuoteCardFontPreset.serif => 'Serif',
    QuoteCardFontPreset.sans => 'Sans',
  };
}

Color _backgroundSwatch(QuoteCardBackgroundPreset value) {
  return switch (value) {
    QuoteCardBackgroundPreset.mist => const Color(0xFFE7E4DD),
    QuoteCardBackgroundPreset.paper => const Color(0xFFF1E2BA),
    QuoteCardBackgroundPreset.forest => const Color(0xFFBCD0C0),
    QuoteCardBackgroundPreset.night => const Color(0xFF1E2431),
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
