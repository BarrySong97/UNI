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
  final Map<String, PhoneticsLookupOutcome> _phoneticsCache =
      <String, PhoneticsLookupOutcome>{};
  String _rawSelectedText = '';
  String _normalizedSelectedText = '';
  String? _lookupKey;
  bool _isPhoneticsLoading = false;
  bool _isAiLookupLoading = false;

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
        _isAiLookupLoading = false;
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
      final result = await widget.phoneticsService.lookupWithOutcome(text);
      _phoneticsCache[text] = result;
    } catch (_) {
      _phoneticsCache[text] = PhoneticsLookupOutcome.empty(
        canTryAi: widget.phoneticsService.supportsAiLookup,
      );
    }

    if (!mounted || _lookupKey != text) {
      return;
    }

    setState(() => _isPhoneticsLoading = false);
  }

  Future<void> _lookupPhoneticsWithAi() async {
    final text = _normalizedSelectedText;
    if (text.isEmpty || _isAiLookupLoading) {
      return;
    }

    setState(() => _isAiLookupLoading = true);
    try {
      final result = await widget.phoneticsService.fetchWithAiAndCache(text);
      _phoneticsCache[text] = PhoneticsLookupOutcome(
        result: result,
        foundLocally: false,
        foundInAiCache: true,
        canTryAi: widget.phoneticsService.supportsAiLookup,
      );
    } on PhoneticsAiNotConfiguredException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI phonetics is not configured. Set it up in Settings.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI phonetics lookup failed.')),
        );
      }
    }

    if (!mounted || _normalizedSelectedText != text) {
      return;
    }
    setState(() => _isAiLookupLoading = false);
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
      aiButtonLabel: _showAiButton ? 'AI' : null,
      onAiPressed: _showAiButton ? _lookupPhoneticsWithAi : null,
      isAiLoading: _isAiLookupLoading,
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

    final outcome = _phoneticsCache[_normalizedSelectedText];
    final phonetics = outcome?.result;
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

  bool get _showAiButton {
    if (_normalizedSelectedText.isEmpty || _isPhoneticsLoading) {
      return false;
    }
    final outcome = _phoneticsCache[_normalizedSelectedText];
    if (outcome == null) {
      return false;
    }
    return !outcome.result.hasAny && outcome.canTryAi;
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
