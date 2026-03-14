import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../services/reader/models/reader_preferences.dart';

/// Font & layout settings panel shown above the bottom toolbar.
class ReaderFontPanel extends StatelessWidget {
  const ReaderFontPanel({
    super.key,
    required this.preferences,
    required this.onPreferencesChanged,
  });

  final ReaderPreferences preferences;
  final ValueChanged<ReaderPreferences> onPreferencesChanged;

  Color get _textColor => preferences.theme.textColor;

  bool get _isDark => preferences.theme == ReaderTheme.dark;

  Color get _segmentBorder =>
      _isDark ? Colors.grey.shade600 : Colors.grey.shade400;

  Color get _segmentSelectedBg =>
      _isDark ? Colors.grey.shade700 : Colors.grey.shade300;

  // ---------------------------------------------------------------------------
  // Margin & line-spacing presets
  // ---------------------------------------------------------------------------

  static const _marginPresets = <String, double>{
    'SM': 16.0,
    'Margin': 24.0,
    'LG': 36.0,
  };

  static const _lineHeightPresets = <String, double>{
    'Tight': 1.2,
    'Spacing': 1.6,
    'Loose': 2.0,
  };

  String _currentMarginLabel() {
    for (final e in _marginPresets.entries) {
      if ((preferences.pageHorizontalPaddingPx - e.value).abs() < 1) {
        return e.key;
      }
    }
    return 'Margin';
  }

  String _currentLineHeightLabel() {
    for (final e in _lineHeightPresets.entries) {
      if ((preferences.lineHeightMultiplier - e.value).abs() < 0.05) {
        return e.key;
      }
    }
    return 'Spacing';
  }

  // ---------------------------------------------------------------------------
  // System font list
  // ---------------------------------------------------------------------------

  static const _iosFonts = <String>[
    'Athelas',
    'Charter',
    'Georgia',
    'Iowan Old Style',
    'Palatino',
    'Times New Roman',
    'Seravek',
    'Menlo',
  ];

  static const _androidFonts = <String>[
    'serif',
    'monospace',
    'Noto Serif',
    'Roboto Slab',
    'Cutive Mono',
  ];

  static List<String> get _availableFonts {
    try {
      return Platform.isIOS ? _iosFonts : _androidFonts;
    } catch (_) {
      // Fallback for web / desktop.
      return _iosFonts;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: _textColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFontSizeRow(),
          const SizedBox(height: 16),
          _buildSegmentRow(),
          const SizedBox(height: 16),
          _buildFontFamilyRow(context),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Row 1: Font size (small A | number | large A)
  // ---------------------------------------------------------------------------

  Widget _buildFontSizeRow() {
    final size = preferences.baseFontSizePx.round();
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _segmentBorder, width: 0.5),
      ),
      child: Row(
        children: [
          // A- decrease.
          _fontSizeTapArea(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'A',
                  style: TextStyle(
                    color: preferences.baseFontSizePx > 12
                        ? _textColor
                        : _textColor.withValues(alpha: 0.3),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\u2212', // minus sign
                  style: TextStyle(
                    color: preferences.baseFontSizePx > 12
                        ? _textColor
                        : _textColor.withValues(alpha: 0.3),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            onTap: preferences.baseFontSizePx > 12
                ? () => onPreferencesChanged(preferences.copyWith(
                      baseFontSizePx: preferences.baseFontSizePx - 1,
                    ))
                : null,
          ),
          // Current size badge.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: _segmentSelectedBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$size',
              style: TextStyle(
                color: _textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // A+ increase.
          _fontSizeTapArea(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'A',
                  style: TextStyle(
                    color: preferences.baseFontSizePx < 32
                        ? _textColor
                        : _textColor.withValues(alpha: 0.3),
                    fontSize: 21,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '+',
                  style: TextStyle(
                    color: preferences.baseFontSizePx < 32
                        ? _textColor
                        : _textColor.withValues(alpha: 0.3),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            onTap: preferences.baseFontSizePx < 32
                ? () => onPreferencesChanged(preferences.copyWith(
                      baseFontSizePx: preferences.baseFontSizePx + 1,
                    ))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _fontSizeTapArea({required Widget child, VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(child: child),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Row 2: Margin segment + Line spacing segment
  // ---------------------------------------------------------------------------

  Widget _buildSegmentRow() {
    final currentMargin = _currentMarginLabel();
    final currentLineHeight = _currentLineHeightLabel();

    return Row(
      children: [
        // Margin control.
        Expanded(
          child: _buildSegmentControl(
            labels: _marginPresets.keys.toList(),
            selected: currentMargin,
            onSelected: (label) {
              final value = _marginPresets[label]!;
              onPreferencesChanged(preferences.copyWith(
                pageHorizontalPaddingPx: value,
              ));
            },
          ),
        ),
        const SizedBox(width: 12),
        // Line spacing control.
        Expanded(
          child: _buildSegmentControl(
            labels: _lineHeightPresets.keys.toList(),
            selected: currentLineHeight,
            onSelected: (label) {
              final value = _lineHeightPresets[label]!;
              onPreferencesChanged(preferences.copyWith(
                lineHeightMultiplier: value,
              ));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentControl({
    required List<String> labels,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _segmentBorder, width: 0.5),
      ),
      child: Row(
        children: labels.map((label) {
          final isSelected = label == selected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(label),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? _segmentSelectedBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                margin: const EdgeInsets.all(3),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? _textColor
                        : _textColor.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Row 3: Font family picker
  // ---------------------------------------------------------------------------

  Widget _buildFontFamilyRow(BuildContext context) {
    final displayName = preferences.fontFamily ?? 'System Default';

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showFontPicker(context),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _segmentBorder, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 14,
                        fontFamily: preferences.fontFamily,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: _textColor.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Font picker bottom sheet
  // ---------------------------------------------------------------------------

  void _showFontPicker(BuildContext context) {
    final barColor = _isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final fonts = _availableFonts;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: barColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar.
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _textColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Font',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // System Default option.
                    _fontListTile(
                      context: ctx,
                      displayName: 'System Default',
                      fontFamily: null,
                      isSelected: preferences.fontFamily == null,
                    ),
                    ...fonts.map((font) => _fontListTile(
                          context: ctx,
                          displayName: font,
                          fontFamily: font,
                          isSelected: preferences.fontFamily == font,
                        )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fontListTile({
    required BuildContext context,
    required String displayName,
    required String? fontFamily,
    required bool isSelected,
  }) {
    return ListTile(
      title: Text(
        displayName,
        style: TextStyle(
          color: _textColor,
          fontSize: 17,
          fontFamily: fontFamily,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: Colors.blue, size: 22)
          : null,
      onTap: () {
        Navigator.pop(context);
        if (fontFamily == null) {
          onPreferencesChanged(preferences.copyWith(clearFontFamily: true));
        } else {
          onPreferencesChanged(preferences.copyWith(fontFamily: fontFamily));
        }
      },
    );
  }
}
