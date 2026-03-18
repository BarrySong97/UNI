import 'package:flutter/material.dart';

import '../../../services/reader/models/parsed_chapter.dart';
import '../../../services/reader/models/reader_preferences.dart';
import 'reader_pill_slider.dart';

/// Inline panel with a draggable progress bar for jumping to a book position.
class ReaderProgressPanel extends StatefulWidget {
  const ReaderProgressPanel({
    super.key,
    required this.bookPercent,
    required this.chapters,
    required this.preferences,
    required this.onPercentChanged,
  });

  final double bookPercent;
  final List<ParsedChapter> chapters;
  final ReaderPreferences preferences;
  final ValueChanged<double> onPercentChanged;

  @override
  State<ReaderProgressPanel> createState() => _ReaderProgressPanelState();
}

class _ReaderProgressPanelState extends State<ReaderProgressPanel> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.bookPercent;
  }

  @override
  void didUpdateWidget(covariant ReaderProgressPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookPercent != widget.bookPercent) {
      _value = widget.bookPercent;
    }
  }

  /// Compute the chapter title for a given percent position.
  String _chapterTitleAt(double percent) {
    final chapters = widget.chapters;
    if (chapters.isEmpty) return '';
    final chapterFraction = 1.0 / chapters.length;
    final index =
        (percent / chapterFraction).floor().clamp(0, chapters.length - 1);
    final chapter = chapters[index];
    return chapter.title.isNotEmpty
        ? chapter.title
        : 'Chapter ${index + 1}';
  }

  Color get _text => widget.preferences.theme.textColor;

  @override
  Widget build(BuildContext context) {
    final chapterTitle = _chapterTitleAt(_value);

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
            onChangeEnd: () => widget.onPercentChanged(_value),
            onDecrement: () {
              final v = (_value - 0.01).clamp(0.0, 1.0);
              setState(() => _value = v);
              widget.onPercentChanged(v);
            },
            onIncrement: () {
              final v = (_value + 0.01).clamp(0.0, 1.0);
              setState(() => _value = v);
              widget.onPercentChanged(v);
            },
          ),
          const SizedBox(height: 4),
          // Percent label.
          Text(
            '${(_value * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              color: _text.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
