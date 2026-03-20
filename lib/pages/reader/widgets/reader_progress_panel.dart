import 'package:flutter/material.dart';

import '../../../services/reader/models/reader_preferences.dart';
import 'reader_pill_slider.dart';

/// Inline panel with a draggable progress bar for jumping to a book position.
class ReaderProgressPanel extends StatefulWidget {
  const ReaderProgressPanel({
    super.key,
    required this.bookPercent,
    required this.chapterTitleForPercent,
    required this.preferences,
    required this.onPercentChanged,
  });

  final double bookPercent;
  final String Function(double percent) chapterTitleForPercent;
  final ReaderPreferences preferences;
  final ValueChanged<double> onPercentChanged;

  @override
  State<ReaderProgressPanel> createState() => _ReaderProgressPanelState();
}

class _ReaderProgressPanelState extends State<ReaderProgressPanel> {
  late double _value;
  bool _awaitingCommit = false;
  double _preRequestSourceValue = 0.0;

  @override
  void initState() {
    super.initState();
    _value = widget.bookPercent;
    _preRequestSourceValue = widget.bookPercent;
  }

  @override
  void didUpdateWidget(covariant ReaderProgressPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookPercent != widget.bookPercent) {
      if (_awaitingCommit) {
        // Ignore one stale bounce to the pre-request value. Commit when a real
        // store update arrives after navigation.
        final bouncedBack =
            (widget.bookPercent - _preRequestSourceValue).abs() < 1e-6;
        if (bouncedBack) {
          return;
        }
        _awaitingCommit = false;
      }
      _value = widget.bookPercent;
    }
  }

  void _requestPercentChange(double value) {
    _awaitingCommit = true;
    _preRequestSourceValue = widget.bookPercent;
    widget.onPercentChanged(value);
  }

  Color get _text => widget.preferences.theme.textColor;

  @override
  Widget build(BuildContext context) {
    final chapterTitle = widget.chapterTitleForPercent(_value);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chapter title — updates as slider moves.
          Text(
            chapterTitle,
            style: TextStyle(
              color: _text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Progress pill slider.
          ReaderPillSlider(
            value: _value,
            textColor: _text,
            onChanged: (v) => setState(() => _value = v),
            onChangeEnd: () => _requestPercentChange(_value),
            onDecrement: () {
              final v = (_value - 0.01).clamp(0.0, 1.0);
              setState(() => _value = v);
              _requestPercentChange(v);
            },
            onIncrement: () {
              final v = (_value + 0.01).clamp(0.0, 1.0);
              setState(() => _value = v);
              _requestPercentChange(v);
            },
          ),
          const SizedBox(height: 4),
          // Percent label.
          Text(
            '${(_value * 100).toStringAsFixed(1)}%',
            style: TextStyle(color: _text.withValues(alpha: 0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
