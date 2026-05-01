import 'package:flutter/material.dart';

import '../../../services/phonetics/phonetics_service.dart';
import '../../../services/tts/tts_service.dart';
import '../../../shared/constants/common-design-tokens.dart';

class ReaderPhoneticsSheet extends StatefulWidget {
  const ReaderPhoneticsSheet({
    super.key,
    required this.selectedText,
    required this.phoneticsService,
    required this.ttsService,
  });

  final String selectedText;
  final PhoneticsService phoneticsService;
  final TtsService ttsService;

  static Future<void> show({
    required BuildContext context,
    required String selectedText,
    required PhoneticsService phoneticsService,
    required TtsService ttsService,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: CommonDesignTokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ReaderPhoneticsSheet(
        selectedText: selectedText,
        phoneticsService: phoneticsService,
        ttsService: ttsService,
      ),
    );
  }

  @override
  State<ReaderPhoneticsSheet> createState() => _ReaderPhoneticsSheetState();
}

class _ReaderPhoneticsSheetState extends State<ReaderPhoneticsSheet> {
  PhoneticsResult? _result;
  PhoneticsLookupOutcome? _outcome;
  bool _loading = true;
  String? _error;
  String? _playingAccent;
  bool _isAiLookupLoading = false;

  @override
  void initState() {
    super.initState();
    widget.ttsService.addListener(_onTtsChanged);
    _lookup();
  }

  @override
  void dispose() {
    widget.ttsService.removeListener(_onTtsChanged);
    super.dispose();
  }

  void _onTtsChanged() {
    if (!widget.ttsService.isSpeaking && _playingAccent != null) {
      if (mounted) setState(() => _playingAccent = null);
    }
  }

  Future<void> _lookup() async {
    try {
      final outcome = await widget.phoneticsService.lookupWithOutcome(
        widget.selectedText,
      );
      if (mounted) {
        setState(() {
          _outcome = outcome;
          _result = outcome.result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
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
      if (mounted) {
        setState(() {
          _result = result;
          _outcome = PhoneticsLookupOutcome(
            result: result,
            foundLocally: false,
            foundInAiCache: true,
            canTryAi: widget.phoneticsService.supportsAiLookup,
          );
        });
      }
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

  Future<void> _play(String accent) async {
    // Map phonetics accent labels to TTS language codes.
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: CommonDesignTokens.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Selected text.
            Text(
              widget.selectedText,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: CommonDesignTokens.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: CommonDesignTokens.textSecondary,
                    fontSize: 14,
                  ),
                ),
              )
            else if (_result != null &&
                (_result!.us.isNotEmpty || _result!.uk.isNotEmpty)) ...[
              if (_result!.us.isNotEmpty)
                _buildPhoneticRow('US', _result!.us, 'us'),
              if (_result!.us.isNotEmpty && _result!.uk.isNotEmpty)
                const SizedBox(height: 12),
              if (_result!.uk.isNotEmpty)
                _buildPhoneticRow('UK', _result!.uk, 'uk'),
            ] else ...[
              _buildPronounceButton(),
              if (_outcome?.canTryAi == true) ...[
                const SizedBox(height: 12),
                _buildAiButton(),
              ],
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneticRow(String label, String ipa, String accent) {
    final isPlaying = _playingAccent == accent && widget.ttsService.isSpeaking;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CommonDesignTokens.pageBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Accent label.
          Container(
            width: 32,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: CommonDesignTokens.textPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // IPA text.
          Expanded(
            child: Text(
              '/$ipa/',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: CommonDesignTokens.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Play button.
          GestureDetector(
            onTap: () => _play(accent),
            child: Icon(
              isPlaying
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
              size: 28,
              color: isPlaying
                  ? CommonDesignTokens.textPrimary
                  : CommonDesignTokens.headerLabelColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPronounceButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _play(
          widget.ttsService.defaultEnglishAccent == 'en_GB' ? 'uk' : 'us',
        ),
        icon: const Icon(Icons.volume_up),
        label: const Text('Pronounce'),
      ),
    );
  }

  Widget _buildAiButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        key: const ValueKey('reader-phonetics-ai'),
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
    );
  }
}
