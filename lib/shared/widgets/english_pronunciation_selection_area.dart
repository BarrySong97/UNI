import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../services/phonetics/phonetics_service.dart';
import '../../services/tts/tts_service.dart';
import '../utils/pronunciation_selection_text_utils.dart';
import 'pronunciation_selection_toolbar.dart';

class EnglishPronunciationSelectionArea extends StatefulWidget {
  const EnglishPronunciationSelectionArea({
    super.key,
    required this.child,
    required this.phoneticsService,
    required this.ttsService,
    this.preferredLanguageCode,
    this.enabled = true,
  });

  final Widget child;
  final PhoneticsService phoneticsService;
  final TtsService ttsService;
  final String? preferredLanguageCode;
  final bool enabled;

  @override
  State<EnglishPronunciationSelectionArea> createState() =>
      _EnglishPronunciationSelectionAreaState();
}

class _EnglishPronunciationSelectionAreaState
    extends State<EnglishPronunciationSelectionArea> {
  final Map<String, PhoneticsResult> _phoneticsCache =
      <String, PhoneticsResult>{};
  String _rawSelectedText = '';
  String _normalizedSelectedText = '';
  String? _lookupKey;
  bool _isPhoneticsLoading = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return SelectionArea(
      onSelectionChanged: _onSelectionChanged,
      contextMenuBuilder: _buildContextMenu,
      child: widget.child,
    );
  }

  void _onSelectionChanged(SelectedContent? content) {
    final rawText = content?.plainText ?? '';
    final normalizedText = sanitizePronunciationSelectionText(rawText);
    if (rawText == _rawSelectedText &&
        normalizedText == _normalizedSelectedText) {
      return;
    }

    final isWordOrPhrase = _isWordOrPhrase(rawText, normalizedText);
    setState(() {
      _rawSelectedText = rawText;
      _normalizedSelectedText = normalizedText;
      if (!isWordOrPhrase) {
        _lookupKey = null;
        _isPhoneticsLoading = false;
      }
    });

    if (isWordOrPhrase) {
      _lookupPhonetics(normalizedText);
    }
  }

  bool _isWordOrPhrase(String rawText, String normalizedText) {
    if (normalizedText.isEmpty) return false;
    return isPronunciationWordOrPhraseSelection(
      rawSelectedText: rawText,
      normalizedSelectedText: normalizedText,
    );
  }

  Future<void> _lookupPhonetics(String text) async {
    if (_phoneticsCache.containsKey(text)) {
      if (mounted && _isPhoneticsLoading) {
        setState(() => _isPhoneticsLoading = false);
      }
      return;
    }

    _lookupKey = text;
    setState(() => _isPhoneticsLoading = true);

    try {
      final result = await widget.phoneticsService.lookup(text);
      _phoneticsCache[text] = result;
    } catch (_) {
      _phoneticsCache[text] = const PhoneticsResult(us: '', uk: '');
    }

    if (!mounted || _lookupKey != text) {
      return;
    }

    setState(() => _isPhoneticsLoading = false);
  }

  Widget _buildContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    if (!_isWordOrPhrase(_rawSelectedText, _normalizedSelectedText)) {
      return AdaptiveTextSelectionToolbar.selectableRegion(
        selectableRegionState: selectableRegionState,
      );
    }

    ContextMenuButtonItem? copyItem;
    for (final item in selectableRegionState.contextMenuButtonItems) {
      if (item.type == ContextMenuButtonType.copy) {
        copyItem = item;
        break;
      }
    }

    return PronunciationSelectionToolbar(
      anchors: selectableRegionState.contextMenuAnchors,
      ipaLabel: _ipaLabel,
      buttonItems: [
        ContextMenuButtonItem(
          label: 'Pronounce',
          onPressed: () {
            selectableRegionState.hideToolbar();
            _playPronunciation(_normalizedSelectedText);
          },
        ),
        ContextMenuButtonItem(
          type: ContextMenuButtonType.copy,
          onPressed:
              copyItem?.onPressed ??
              () {
                Clipboard.setData(ClipboardData(text: _normalizedSelectedText));
                selectableRegionState.hideToolbar();
              },
        ),
      ],
    );
  }

  String get _resolvedLanguageCode =>
      widget.preferredLanguageCode?.trim().isNotEmpty == true
      ? widget.preferredLanguageCode!.trim()
      : widget.ttsService.defaultEnglishAccent;

  String? get _ipaLabel {
    if (_normalizedSelectedText.isEmpty) {
      return null;
    }

    final phonetics = _phoneticsCache[_normalizedSelectedText];
    if (phonetics == null) {
      return null;
    }

    final preferredIpa = switch (_resolvedLanguageCode) {
      'en_GB' => phonetics.uk,
      'en_US' => phonetics.us,
      _ => phonetics.us.isNotEmpty ? phonetics.us : phonetics.uk,
    };
    if (preferredIpa.isNotEmpty) {
      return '/$preferredIpa/';
    }

    final fallbackIpa = phonetics.us.isNotEmpty ? phonetics.us : phonetics.uk;
    if (fallbackIpa.isNotEmpty) {
      return '/$fallbackIpa/';
    }

    return null;
  }

  Future<void> _playPronunciation(String text) async {
    final model = widget.ttsService.modelInfoForLanguage(_resolvedLanguageCode);
    if (model == null || !widget.ttsService.modelManager.isReady(model)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'TTS model not downloaded. Please download it in Settings.',
            ),
          ),
        );
      }
      return;
    }

    await widget.ttsService.speakWithLanguage(text, _resolvedLanguageCode);
  }
}
