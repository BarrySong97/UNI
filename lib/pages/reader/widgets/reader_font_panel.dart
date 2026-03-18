import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../services/reader/models/reader_preferences.dart';
import 'reader_pill_slider.dart';

/// Font & layout settings panel shown above the bottom toolbar.
class ReaderFontPanel extends StatefulWidget {
  const ReaderFontPanel({
    super.key,
    required this.preferences,
    required this.onPreferencesChanged,
  });

  final ReaderPreferences preferences;
  final ValueChanged<ReaderPreferences> onPreferencesChanged;

  @override
  State<ReaderFontPanel> createState() => _ReaderFontPanelState();
}

class _ReaderFontPanelState extends State<ReaderFontPanel> {
  double? _dragFontSize;

  @override
  void didUpdateWidget(covariant ReaderFontPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences.baseFontSizePx !=
        widget.preferences.baseFontSizePx) {
      _dragFontSize = null;
    }
  }

  ReaderPreferences get _prefs => widget.preferences;
  Color get _text => _prefs.theme.textColor;
  Color get _label => _text.withValues(alpha: 0.5);
  Color get _segBorder => _text.withValues(alpha: 0.15);
  Color get _segSelectedBg => _text.withValues(alpha: 0.1);

  // ---------------------------------------------------------------------------
  // Presets
  // ---------------------------------------------------------------------------

  static const _marginPresets = <String, double>{
    'SM': 16.0,
    'MD': 24.0,
    'LG': 36.0,
  };

  static const _lineHeightPresets = <String, double>{
    '1.2': 1.2,
    '1.6': 1.6,
    '2.0': 2.0,
  };

  static const _paragraphPresets = <String, double>{
    'Tight': 0.5,
    'Normal': 1.0,
    'Loose': 1.5,
  };

  String _matchPreset(Map<String, double> presets, double value, double eps) {
    for (final e in presets.entries) {
      if ((value - e.value).abs() < eps) return e.key;
    }
    return presets.keys.elementAt(1); // default to middle
  }

  // ---------------------------------------------------------------------------
  // Fonts
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
      return _iosFonts;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFontSizeSlider(),
          const SizedBox(height: 20),
          _buildMarginAndLineHeight(),
          const SizedBox(height: 20),
          _buildParagraphSpacing(),
          const SizedBox(height: 20),
          _buildFontFamilyRow(context),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Row 1: Font size pill slider
  // ---------------------------------------------------------------------------

  Widget _buildFontSizeSlider() {
    final size = _dragFontSize ?? _prefs.baseFontSizePx;
    const minVal = 12.0;
    const maxVal = 32.0;
    final normalized =
        ((size - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Font Size',
              style: TextStyle(
                color: _label,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${size.round()}px',
              style: TextStyle(
                color: _text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ReaderPillSlider(
          value: normalized,
          textColor: _text,
          onChanged: (v) {
            final s =
                (minVal + v * (maxVal - minVal)).roundToDouble().clamp(minVal, maxVal);
            setState(() => _dragFontSize = s);
          },
          onChangeEnd: () {
            final s = _dragFontSize;
            if (s != null) {
              widget.onPreferencesChanged(_prefs.copyWith(baseFontSizePx: s));
            }
          },
          onDecrement: () {
            final s = (_prefs.baseFontSizePx - 1).clamp(minVal, maxVal);
            widget.onPreferencesChanged(_prefs.copyWith(baseFontSizePx: s));
          },
          onIncrement: () {
            final s = (_prefs.baseFontSizePx + 1).clamp(minVal, maxVal);
            widget.onPreferencesChanged(_prefs.copyWith(baseFontSizePx: s));
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Row 2: Margin + Line height (side by side)
  // ---------------------------------------------------------------------------

  Widget _buildMarginAndLineHeight() {
    final currentMargin =
        _matchPreset(_marginPresets, _prefs.pageHorizontalPaddingPx, 1);
    final currentLH =
        _matchPreset(_lineHeightPresets, _prefs.lineHeightMultiplier, 0.05);

    return Row(
      children: [
        Expanded(
          child: _buildLabeledSegment(
            label: 'Margin',
            presets: _marginPresets,
            selected: currentMargin,
            onSelected: (label) => widget.onPreferencesChanged(
              _prefs.copyWith(pageHorizontalPaddingPx: _marginPresets[label]),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildLabeledSegment(
            label: 'Line Height',
            presets: _lineHeightPresets,
            selected: currentLH,
            onSelected: (label) => widget.onPreferencesChanged(
              _prefs.copyWith(lineHeightMultiplier: _lineHeightPresets[label]),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Row 3: Paragraph spacing
  // ---------------------------------------------------------------------------

  Widget _buildParagraphSpacing() {
    final current = _matchPreset(
      _paragraphPresets,
      _prefs.paragraphSpacingMultiplier,
      0.1,
    );

    return _buildLabeledSegment(
      label: 'Paragraph Spacing',
      presets: _paragraphPresets,
      selected: current,
      onSelected: (label) => widget.onPreferencesChanged(
        _prefs.copyWith(paragraphSpacingMultiplier: _paragraphPresets[label]),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Row 4: Font family
  // ---------------------------------------------------------------------------

  Widget _buildFontFamilyRow(BuildContext context) {
    final displayName = _prefs.fontFamily ?? 'System Default';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Font',
          style: TextStyle(color: _label, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showFontPicker(context),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _segBorder, width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      color: _text,
                      fontSize: 14,
                      fontFamily: _prefs.fontFamily,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right, color: _label, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Shared: labeled segment control
  // ---------------------------------------------------------------------------

  Widget _buildLabeledSegment({
    required String label,
    required Map<String, double> presets,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: _label, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _segBorder, width: 0.5),
          ),
          child: Row(
            children: presets.keys.map((key) {
              final isSelected = key == selected;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(key),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? _segSelectedBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    margin: const EdgeInsets.all(3),
                    child: Text(
                      key,
                      style: TextStyle(
                        color: isSelected ? _text : _text.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Font picker bottom sheet
  // ---------------------------------------------------------------------------

  void _showFontPicker(BuildContext context) {
    final bgColor = _prefs.theme.backgroundColor;
    final fonts = _availableFonts;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _text.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Font',
                  style: TextStyle(
                    color: _text,
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
                    _fontListTile(
                      context: ctx,
                      displayName: 'System Default',
                      fontFamily: null,
                      isSelected: _prefs.fontFamily == null,
                    ),
                    ...fonts.map((font) => _fontListTile(
                          context: ctx,
                          displayName: font,
                          fontFamily: font,
                          isSelected: _prefs.fontFamily == font,
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
          color: _text,
          fontSize: 17,
          fontFamily: fontFamily,
        ),
      ),
      trailing:
          isSelected ? Icon(Icons.check, color: Colors.blue, size: 22) : null,
      onTap: () {
        Navigator.pop(context);
        if (fontFamily == null) {
          widget.onPreferencesChanged(_prefs.copyWith(clearFontFamily: true));
        } else {
          widget.onPreferencesChanged(_prefs.copyWith(fontFamily: fontFamily));
        }
      },
    );
  }
}
