import 'package:flutter/material.dart';

import '../../../services/phonetics/phonetics_service.dart';
import '../../../services/tts/tts_service.dart';
import '../../../shared/constants/common-design-tokens.dart';

class WordPronunciationRow extends StatefulWidget {
  const WordPronunciationRow({
    required this.selectedText,
    required this.phoneticsService,
    required this.ttsService,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String selectedText;
  final PhoneticsService phoneticsService;
  final TtsService ttsService;
  final EdgeInsetsGeometry padding;

  @override
  State<WordPronunciationRow> createState() => _WordPronunciationRowState();
}

class _WordPronunciationRowState extends State<WordPronunciationRow> {
  PhoneticsResult? _phonetics;
  PhoneticsLookupOutcome? _outcome;
  String? _playingAccent;
  bool _isAiLookupLoading = false;

  @override
  void initState() {
    super.initState();
    widget.ttsService.addListener(_onTtsChanged);
    _lookupPhonetics();
  }

  @override
  void didUpdateWidget(covariant WordPronunciationRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ttsService != widget.ttsService) {
      oldWidget.ttsService.removeListener(_onTtsChanged);
      widget.ttsService.addListener(_onTtsChanged);
    }
    if (oldWidget.selectedText != widget.selectedText ||
        oldWidget.phoneticsService != widget.phoneticsService) {
      _phonetics = null;
      _outcome = null;
      _playingAccent = null;
      _isAiLookupLoading = false;
      _lookupPhonetics();
    }
  }

  @override
  void dispose() {
    widget.ttsService.removeListener(_onTtsChanged);
    super.dispose();
  }

  void _onTtsChanged() {
    if (!widget.ttsService.isSpeaking && _playingAccent != null && mounted) {
      setState(() => _playingAccent = null);
    }
  }

  Future<void> _lookupPhonetics() async {
    try {
      final outcome = await widget.phoneticsService.lookupWithOutcome(
        widget.selectedText,
      );
      if (!mounted) return;
      setState(() {
        _phonetics = outcome.result;
        _outcome = outcome;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phonetics = const PhoneticsResult(us: '', uk: '');
        _outcome = PhoneticsLookupOutcome.empty(
          canTryAi: widget.phoneticsService.supportsAiLookup,
        );
      });
    }
  }

  Future<void> _lookupWithAi() async {
    if (_isAiLookupLoading) {
      return;
    }

    setState(() => _isAiLookupLoading = true);
    try {
      final result = await widget.phoneticsService.fetchWithAiAndCache(
        widget.selectedText,
      );
      if (!mounted) return;
      setState(() {
        _phonetics = result;
        _outcome = PhoneticsLookupOutcome(
          result: result,
          foundLocally: false,
          foundInAiCache: true,
          canTryAi: widget.phoneticsService.supportsAiLookup,
        );
      });
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
    if (mounted) {
      setState(() => _isAiLookupLoading = false);
    }
  }

  Future<void> _playPronunciation(String accent) async {
    final languageCode = accent == 'uk' ? 'en_GB' : 'en_US';
    final model = widget.ttsService.modelInfoForLanguage(languageCode);
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
    if (_playingAccent == accent && widget.ttsService.isSpeaking) {
      await widget.ttsService.stop();
      return;
    }
    setState(() => _playingAccent = accent);
    await widget.ttsService.speakWithLanguage(
      widget.selectedText,
      languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final phonetics = _phonetics;
    if (phonetics == null) {
      return const SizedBox.shrink();
    }

    if (phonetics.us.isEmpty && phonetics.uk.isEmpty) {
      if (_outcome?.canTryAi != true) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: widget.padding,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('word-pronunciation-ai'),
            onPressed: _isAiLookupLoading ? null : _lookupWithAi,
            icon: _isAiLookupLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: const Text('AI'),
          ),
        ),
      );
    }

    final usChip = phonetics.us.isNotEmpty
        ? _buildAccentChip('US', phonetics.us, 'us')
        : null;
    final ukChip = phonetics.uk.isNotEmpty
        ? _buildAccentChip('UK', phonetics.uk, 'uk')
        : null;
    final chips = [if (usChip != null) usChip, if (ukChip != null) ukChip];

    final content = chips.length == 1
        ? chips.first
        : LayoutBuilder(
            builder: (context, constraints) {
              final estimatedWidth =
                  (phonetics.us.length + phonetics.uk.length) * 8.0 +
                  52 * 2 +
                  16;
              if (estimatedWidth > constraints.maxWidth) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [chips[0], const SizedBox(height: 4), chips[1]],
                );
              }
              return Row(
                children: [chips[0], const SizedBox(width: 16), chips[1]],
              );
            },
          );

    return Padding(padding: widget.padding, child: content);
  }

  Widget _buildAccentChip(String label, String ipa, String accent) {
    final isPlaying = _playingAccent == accent && widget.ttsService.isSpeaking;

    return GestureDetector(
      key: ValueKey<String>('word-pronunciation-$accent'),
      onTap: () => _playPronunciation(accent),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CommonDesignTokens.pageBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '/$ipa/',
                style: const TextStyle(
                  fontSize: 14,
                  color: CommonDesignTokens.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isPlaying ? Icons.stop_circle_outlined : Icons.volume_up,
              size: 18,
              color: isPlaying
                  ? CommonDesignTokens.textPrimary
                  : CommonDesignTokens.headerLabelColor,
            ),
          ],
        ),
      ),
    );
  }
}
