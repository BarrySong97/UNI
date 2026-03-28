import 'package:flutter/material.dart';

import '../../app/providers/app-providers.dart';
import '../../services/ai/ai_settings_service.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/form-design-tokens.dart';
import '../../shared/constants/settings-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';

class OnboardingAiStep extends StatefulWidget {
  const OnboardingAiStep({
    required this.onContinue,
    required this.onSkip,
    super.key,
  });

  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  State<OnboardingAiStep> createState() => _OnboardingAiStepState();
}

class _OnboardingAiStepState extends State<OnboardingAiStep> {
  TextEditingController? _baseUrlController;
  TextEditingController? _apiKeyController;
  bool _obscureKey = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_baseUrlController != null) return;
    final ai = AppProvidersScope.of(context).aiSettingsService;
    _baseUrlController = TextEditingController(text: ai.baseUrl);
    _apiKeyController = TextEditingController(text: ai.apiKey);
  }

  @override
  void dispose() {
    _baseUrlController?.dispose();
    _apiKeyController?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ai = AppProvidersScope.of(context).aiSettingsService;
    await ai.updateGlobal(
      baseUrl: _baseUrlController!.text.trim(),
      apiKey: _apiKeyController!.text.trim(),
    );
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommonDesignTokens.pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // --- Top: Illustration ---
                    Column(
                      children: [
                        const SizedBox(height: 24),
                        const _AiIllustration(),
                        const SizedBox(height: 28),
                        Text(
                          'AI-Powered Explanation',
                          style: TextStyle(
                            fontSize: CommonDesignTokens.headerTitleSize,
                            fontWeight: FontWeight.w700,
                            color: CommonDesignTokens.textPrimary,
                            height: 0.95,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Select any word while reading to get an instant, context-aware explanation powered by AI.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: FormDesignTokens.fieldLabelSize,
                            color: CommonDesignTokens.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                    // --- Middle: Input fields ---
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: _buildInputCard(),
                    ),
                    // --- Bottom: Buttons ---
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: FormDesignTokens.buttonHeight,
                          child: FilledButton(
                            onPressed: _save,
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
                                fontWeight: FormDesignTokens.buttonFontWeight,
                              ),
                            ),
                            child: const Text('Continue'),
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
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Column(
        children: [
          _buildFieldRow(
            icon: Icons.link_outlined,
            label: 'Base URL',
            controller: _baseUrlController!,
            hintText: AiSettingsService.defaultBaseUrl,
            keyboardType: TextInputType.url,
          ),
          _buildDivider(),
          _buildFieldRow(
            icon: Icons.key_outlined,
            label: 'API Key',
            controller: _apiKeyController!,
            hintText: 'sk-...',
            obscureText: _obscureKey,
            trailing: GestureDetector(
              onTap: () => setState(() => _obscureKey = !_obscureKey),
              child: Icon(
                _obscureKey
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? trailing,
  }) {
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
              child: Icon(
                icon,
                size: 20,
                color: CommonDesignTokens.headerLabelColor,
              ),
            ),
            const SizedBox(width: FormDesignTokens.fieldIconGap),
            SizedBox(
              width: FormDesignTokens.fieldLabelWidth,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: FormDesignTokens.fieldLabelSize,
                  fontWeight: FontWeight.w500,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: FormDesignTokens.fieldLabelGap),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: FormDesignTokens.fieldValueSize,
                  color: CommonDesignTokens.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontSize: FormDesignTokens.fieldValueSize,
                    color: CommonDesignTokens.textSecondary.withValues(
                      alpha: FormDesignTokens.fieldHintOpacity,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: FormDesignTokens.dividerIndent),
      child: Container(
        height: FormDesignTokens.dividerThickness,
        color: FormDesignTokens.dividerColor,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Illustration: simulates selecting a word and getting an AI explanation
// ---------------------------------------------------------------------------

class _AiIllustration extends StatelessWidget {
  const _AiIllustration();

  static const _cardBg = ShelfDesignTokens.statsCardBg; // #FAF9F7
  static const _accentColor = CommonDesignTokens.headerLabelColor; // #8B7355
  static const _highlightColor = Color(0xFFFFF3C4);
  static const _textColor = CommonDesignTokens.textPrimary;
  static const _mutedColor = ShelfDesignTokens.statsNumberColor; // #5C4A3A

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simulated book text with a highlighted word
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 15,
                color: _textColor.withValues(alpha: 0.7),
                height: 1.6,
              ),
              children: [
                const TextSpan(
                  text: '...the old man sat quietly\n'
                      'in the corner, his eyes filled\n'
                      'with ',
                ),
                WidgetSpan(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: _highlightColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'nostalgia',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ' ...'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // AI explanation card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CommonDesignTokens.cardBg,
              borderRadius: BorderRadius.circular(
                ShelfDesignTokens.statsCardRadius,
              ),
              border: Border.all(
                color: _accentColor.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: _accentColor),
                    const SizedBox(width: 6),
                    Text(
                      'AI',
                      style: TextStyle(
                        fontSize: CommonDesignTokens.headerLabelSize,
                        fontWeight: FontWeight.w600,
                        color: _accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'nostalgia  (n.)',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: FormDesignTokens.fieldLabelSize,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A sentimental longing or wistful affection for a period in the past.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _mutedColor.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
