import 'package:flutter/material.dart';

import '../../services/tts/tts_model_config.dart';
import '../../services/tts/tts_model_manager.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/form-design-tokens.dart';
import '../../shared/constants/settings-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';

class OnboardingVoiceStep extends StatefulWidget {
  const OnboardingVoiceStep({
    required this.modelManager,
    required this.onVoiceSelected,
    required this.onContinue,
    required this.onSkip,
    this.onBack,
    super.key,
  });

  final TtsModelManager modelManager;
  final Future<void> Function(String languageCode, String voiceKey)
  onVoiceSelected;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback? onBack;

  @override
  State<OnboardingVoiceStep> createState() => _OnboardingVoiceStepState();
}

class _OnboardingVoiceStepState extends State<OnboardingVoiceStep> {
  static const _models = [TtsBuiltinModels.usModel, TtsBuiltinModels.ukModel];
  static const _labels = ['English (US)', 'English (UK)'];
  static const _langCodes = ['en_US', 'en_GB'];

  late TtsModelManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = widget.modelManager;
    _manager.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(covariant OnboardingVoiceStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.modelManager, widget.modelManager)) {
      oldWidget.modelManager.removeListener(_onStateChanged);
      _manager = widget.modelManager;
      _manager.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    _manager.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _startDownload(int index) async {
    final model = _models[index];
    await _manager.downloadModel(model);
    if (!mounted) return;
    if (_manager.isReady(model)) {
      await widget.onVoiceSelected(_langCodes[index], model.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommonDesignTokens.pageBackground,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 24,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: 24),
                        // --- Middle-bottom: Illustration + title + download ---
                        Column(
                          children: [
                            const _VoiceIllustration(),
                            const SizedBox(height: 16),
                            Text(
                              'Offline Pronunciation',
                              style: TextStyle(
                                fontSize: CommonDesignTokens.headerTitleSize,
                                fontWeight: FontWeight.w700,
                                color: CommonDesignTokens.textPrimary,
                                height: 0.95,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Download voice models to hear word pronunciations anytime — no internet needed.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: FormDesignTokens.fieldLabelSize,
                                color: CommonDesignTokens.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            // --- Download cards ---
                            _buildDownloadList(),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // --- Bottom: Buttons ---
                        Column(
                          children: [
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: FormDesignTokens.buttonHeight,
                              child: FilledButton(
                                onPressed: widget.onContinue,
                                style: FilledButton.styleFrom(
                                  backgroundColor: FormDesignTokens.buttonBg,
                                  foregroundColor: FormDesignTokens.buttonText,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      CommonDesignTokens.cardRadius,
                                    ),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: FormDesignTokens.buttonFontSize,
                                    fontWeight:
                                        FormDesignTokens.buttonFontWeight,
                                  ),
                                ),
                                child: const Text('Get Started'),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: widget.onSkip,
                              child: const Text(
                                'Skip',
                                style: TextStyle(
                                  fontSize: FormDesignTokens.fieldLabelSize,
                                  color: CommonDesignTokens.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Back button — pinned at top-left, above SafeArea content
            if (widget.onBack != null)
              Positioned(
                top: 0,
                left: 4,
                child: IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 20,
                    color: CommonDesignTokens.textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadList() {
    return Container(
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _models.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(
                  left: FormDesignTokens.dividerIndent,
                ),
                child: Container(
                  height: FormDesignTokens.dividerThickness,
                  color: FormDesignTokens.dividerColor,
                ),
              ),
            _buildModelRow(i),
          ],
        ],
      ),
    );
  }

  Widget _buildModelRow(int index) {
    final model = _models[index];
    final state = _manager.stateOf(model);
    final label = _labels[index];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: FormDesignTokens.fieldRowHeight,
        child: Row(
          children: [
            Container(
              width: SettingsDesignTokens.settingsRowIconContainerSize,
              height: SettingsDesignTokens.settingsRowIconContainerSize,
              decoration: BoxDecoration(
                color: SettingsDesignTokens.settingsRowIconContainerBg,
                borderRadius: BorderRadius.circular(
                  SettingsDesignTokens.settingsRowIconContainerRadius,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.graphic_eq,
                size: 20,
                color: CommonDesignTokens.headerLabelColor,
              ),
            ),
            const SizedBox(width: FormDesignTokens.fieldIconGap),
            Expanded(child: _buildStatusContent(state, label, index)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent(TtsModelState state, String label, int index) {
    final model = _models[index];
    switch (state.status) {
      case TtsModelStatus.notDownloaded:
        return Row(
          children: [
            Expanded(
              child: Text(
                '$label · ~${model.estimatedSizeMB} MB',
                style: const TextStyle(
                  fontSize: FormDesignTokens.fieldValueSize,
                  color: CommonDesignTokens.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _startDownload(index),
              child: Text(
                'Download',
                style: TextStyle(
                  fontSize: FormDesignTokens.fieldLabelSize,
                  fontWeight: FontWeight.w600,
                  color: CommonDesignTokens.headerLabelColor,
                ),
              ),
            ),
          ],
        );
      case TtsModelStatus.downloading:
        final pct = (state.progress * 100).toInt();
        return Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label · $pct%',
                    style: const TextStyle(
                      fontSize: FormDesignTokens.fieldValueSize,
                      color: CommonDesignTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: state.progress,
                      minHeight: 3,
                      backgroundColor: ShelfDesignTokens.homeGridProgressBg,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        ShelfDesignTokens.homeGridProgressFill,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case TtsModelStatus.extracting:
        return Row(
          children: [
            Expanded(
              child: Text(
                '$label · Extracting...',
                style: const TextStyle(
                  fontSize: FormDesignTokens.fieldValueSize,
                  color: CommonDesignTokens.textPrimary,
                ),
              ),
            ),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  CommonDesignTokens.headerLabelColor,
                ),
              ),
            ),
          ],
        );
      case TtsModelStatus.ready:
        return Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: FormDesignTokens.fieldValueSize,
                  color: CommonDesignTokens.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.check_circle, size: 20, color: Color(0xFF5F7A5E)),
          ],
        );
      case TtsModelStatus.error:
        return Row(
          children: [
            Expanded(
              child: Text(
                '$label · Failed',
                style: const TextStyle(
                  fontSize: FormDesignTokens.fieldValueSize,
                  color: Colors.red,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () => _startDownload(index),
              child: Text(
                'Retry',
                style: TextStyle(
                  fontSize: FormDesignTokens.fieldLabelSize,
                  fontWeight: FontWeight.w600,
                  color: CommonDesignTokens.headerLabelColor,
                ),
              ),
            ),
          ],
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Illustration: simulates a word card with phonetics and a play button
// ---------------------------------------------------------------------------

class _VoiceIllustration extends StatelessWidget {
  const _VoiceIllustration();

  static const _cardBg = ShelfDesignTokens.statsCardBg;
  static const _accentColor = CommonDesignTokens.headerLabelColor;
  static const _textColor = CommonDesignTokens.textPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Column(
        children: [
          const Text(
            'nostalgia',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: CommonDesignTokens.headerTitleSize,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '/nɒˈstæl.dʒə/',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 17,
              color: _accentColor,
            ),
          ),
          const SizedBox(height: 20),
          // Play button with sound waves
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: _accentColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 10),
              // Sound wave bars
              ...List.generate(5, (i) {
                final heights = [12.0, 20.0, 28.0, 18.0, 10.0];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 4,
                    height: heights[i],
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.3 + i * 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
