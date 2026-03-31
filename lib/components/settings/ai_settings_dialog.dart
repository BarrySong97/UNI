import 'package:flutter/material.dart';

import '../../services/ai/ai_settings_service.dart';
import '../../services/tts/tts_service.dart';
import '../../services/tts/tts_voice_catalog.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/form-design-tokens.dart';
import '../../shared/constants/settings-design-tokens.dart';
import '../../shared/layout/responsive_layout.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({
    super.key,
    required this.aiSettings,
    required this.ttsService,
  });

  final AiSettingsService aiSettings;
  final TtsService ttsService;

  static void push(
    BuildContext context,
    AiSettingsService aiSettings,
    TtsService ttsService,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AiSettingsPage(aiSettings: aiSettings, ttsService: ttsService),
      ),
    );
  }

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: widget.aiSettings.baseUrl);
    _apiKeyController = TextEditingController(text: widget.aiSettings.apiKey);
    widget.aiSettings.addListener(_onSettingsChange);
    widget.ttsService.addListener(_onTtsChange);
  }

  @override
  void dispose() {
    widget.aiSettings.removeListener(_onSettingsChange);
    widget.ttsService.removeListener(_onTtsChange);
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _onSettingsChange() {
    if (mounted) setState(() {});
  }

  void _onTtsChange() {
    if (mounted) setState(() {});
  }

  TtsVoiceCatalog get _catalog => widget.ttsService.catalog;

  @override
  Widget build(BuildContext context) {
    final configuredLanguages = widget.ttsService.configuredLanguages;

    return Scaffold(
      backgroundColor: CommonDesignTokens.pageBackground,
      appBar: AppBar(
        backgroundColor: CommonDesignTokens.pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: CommonDesignTokens.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'AI Settings',
          style: TextStyle(
            fontSize: CommonDesignTokens.bookTitleSize,
            fontWeight: FontWeight.w700,
            color: CommonDesignTokens.textPrimary,
          ),
        ),
      ),
      body: ResponsiveContentWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CONNECTION section
              const _SectionLabel(label: 'CONNECTION'),
            const SizedBox(height: 12),
            _buildCard(
              children: [
                _buildFieldRow(
                  icon: Icons.link_outlined,
                  label: 'Base URL',
                  controller: _baseUrlController,
                  hintText: 'https://api.openai.com/v1',
                  keyboardType: TextInputType.url,
                ),
                _buildDivider(),
                _buildFieldRow(
                  icon: Icons.key_outlined,
                  label: 'API Key',
                  controller: _apiKeyController,
                  hintText: 'sk-...',
                  obscureText: _obscureApiKey,
                  trailing: GestureDetector(
                    onTap: () =>
                        setState(() => _obscureApiKey = !_obscureApiKey),
                    child: Icon(
                      _obscureApiKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: CommonDesignTokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // LANGUAGES section
            const _SectionLabel(label: 'LANGUAGES'),
            const SizedBox(height: 12),
            if (configuredLanguages.isEmpty)
              _buildCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Text(
                      'Configure languages in TTS settings first.',
                      style: TextStyle(
                        fontSize: FormDesignTokens.fieldLabelSize,
                        color: CommonDesignTokens.textSecondary.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            else
              _buildCard(
                children: [
                  for (int i = 0; i < configuredLanguages.length; i++) ...[
                    if (i > 0) _buildDivider(),
                    _buildLanguageRow(configuredLanguages[i]),
                  ],
                ],
              ),
            const SizedBox(height: 32),

            // Save button (saves global connection settings)
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
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 24),
          ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Language row
  // ---------------------------------------------------------------------------

  Widget _buildLanguageRow(String languageCode) {
    final group = _catalog.languageGroups[languageCode];
    final langLabel = group?.displayLabel ?? languageCode;
    final config = widget.aiSettings.configForLanguage(languageCode);
    final hasCustomConfig = widget.aiSettings.configMap.containsKey(
      languageCode,
    );

    final subtitle = hasCustomConfig
        ? _configSummary(config)
        : 'Default — tap to configure';

    return GestureDetector(
      onTap: () => _showLanguageConfigSheet(languageCode),
      behavior: HitTestBehavior.opaque,
      child: Padding(
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
                  Icons.smart_toy_outlined,
                  size: 20,
                  color: CommonDesignTokens.headerLabelColor,
                ),
              ),
              const SizedBox(width: FormDesignTokens.fieldIconGap),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      langLabel,
                      style: const TextStyle(
                        fontSize: FormDesignTokens.fieldLabelSize,
                        fontWeight: FontWeight.w500,
                        color: CommonDesignTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: hasCustomConfig
                            ? CommonDesignTokens.textSecondary
                            : CommonDesignTokens.textSecondary.withValues(
                                alpha: 0.6,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 22,
                color: CommonDesignTokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _configSummary(AiLanguageConfig config) {
    final parts = <String>[config.model];
    parts.add(_detailLabel(config.detail));
    if (config.explanationLanguage.isNotEmpty) {
      parts.add(config.explanationLanguage);
    }
    return parts.join(' · ');
  }

  static String _detailLabel(ExplanationDetail detail) {
    switch (detail) {
      case ExplanationDetail.brief:
        return 'Brief';
      case ExplanationDetail.balanced:
        return 'Balanced';
      case ExplanationDetail.detailed:
        return 'Detailed';
    }
  }

  // ---------------------------------------------------------------------------
  // Card & Divider helpers
  // ---------------------------------------------------------------------------

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Column(children: children),
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

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _showLanguageConfigSheet(String languageCode) {
    final group = _catalog.languageGroups[languageCode];
    final langLabel = group?.displayLabel ?? languageCode;
    final currentConfig = widget.aiSettings.configForLanguage(languageCode);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CommonDesignTokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return _AiLanguageConfigSheet(
          languageCode: languageCode,
          languageLabel: langLabel,
          config: currentConfig,
          onSave: (config) {
            widget.aiSettings.setConfigForLanguage(languageCode, config);
            Navigator.of(ctx).pop();
          },
          onReset: () {
            widget.aiSettings.removeConfigForLanguage(languageCode);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  Future<void> _save() async {
    await widget.aiSettings.updateGlobal(
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }
}

// =============================================================================
// Per-language AI config bottom sheet
// =============================================================================

class _AiLanguageConfigSheet extends StatefulWidget {
  const _AiLanguageConfigSheet({
    required this.languageCode,
    required this.languageLabel,
    required this.config,
    required this.onSave,
    required this.onReset,
  });

  final String languageCode;
  final String languageLabel;
  final AiLanguageConfig config;
  final void Function(AiLanguageConfig config) onSave;
  final VoidCallback onReset;

  @override
  State<_AiLanguageConfigSheet> createState() => _AiLanguageConfigSheetState();
}

class _AiLanguageConfigSheetState extends State<_AiLanguageConfigSheet> {
  late final TextEditingController _modelController;
  late final TextEditingController _promptController;
  late ExplanationDetail _detail;

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(text: widget.config.model);
    _promptController = TextEditingController(text: widget.config.customPrompt);
    _detail = widget.config.detail;
  }

  @override
  void dispose() {
    _modelController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FormDesignTokens.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.languageLabel,
                style: const TextStyle(
                  fontSize: CommonDesignTokens.bookTitleSize,
                  fontWeight: FontWeight.w700,
                  color: CommonDesignTokens.textPrimary,
                ),
              ),
            ),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                children: [
                  // MODEL section
                  const _SectionLabel(label: 'MODEL'),
                  const SizedBox(height: 8),
                  _buildCard(
                    children: [
                      _buildInlineFieldRow(
                        icon: Icons.smart_toy_outlined,
                        label: 'Model',
                        controller: _modelController,
                        hintText: AiSettingsService.defaultModel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // DETAIL section
                  const _SectionLabel(label: 'DETAIL'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final detail in ExplanationDetail.values) ...[
                        if (detail.index > 0)
                          const SizedBox(width: CommonDesignTokens.tabGap),
                        _buildDetailTab(detail),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // CUSTOM PROMPT section
                  const _SectionLabel(label: 'CUSTOM PROMPT'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(
                      FormDesignTokens.textareaPadding,
                    ),
                    decoration: BoxDecoration(
                      color: CommonDesignTokens.pageBackground,
                      borderRadius: BorderRadius.circular(
                        CommonDesignTokens.cardRadius,
                      ),
                    ),
                    child: TextField(
                      controller: _promptController,
                      maxLines: FormDesignTokens.textareaMaxLines,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontSize: FormDesignTokens.textareaSize,
                        color: CommonDesignTokens.textPrimary,
                        height: FormDesignTokens.textareaLineHeight,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Leave empty to use default prompt...',
                        hintStyle: TextStyle(
                          fontSize: FormDesignTokens.textareaSize,
                          color: CommonDesignTokens.textSecondary.withValues(
                            alpha: FormDesignTokens.textareaHintOpacity,
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: FormDesignTokens.helperHorizontalPadding,
                    ),
                    child: Text(
                      'Use {bookTitle}, {selectedText}, and {context} as '
                      'placeholders. Leave empty to use the default template.',
                      style: TextStyle(
                        fontSize: FormDesignTokens.helperSize,
                        color: CommonDesignTokens.textSecondary,
                        height: FormDesignTokens.helperLineHeight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // Bottom buttons
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: widget.onReset,
                      child: const Text(
                        'Reset',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _saveConfig,
                      style: FilledButton.styleFrom(
                        backgroundColor: FormDesignTokens.buttonBg,
                        foregroundColor: FormDesignTokens.buttonText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            CommonDesignTokens.cardRadius,
                          ),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailTab(ExplanationDetail detail) {
    final selected = _detail == detail;
    final label = _detailLabel(detail);
    return GestureDetector(
      onTap: () => setState(() => _detail = detail),
      child: Container(
        height: CommonDesignTokens.tabHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: CommonDesignTokens.tabHorizontalPadding,
        ),
        decoration: BoxDecoration(
          color: selected
              ? CommonDesignTokens.tabActiveBg
              : CommonDesignTokens.tabInactiveBg,
          borderRadius: BorderRadius.circular(
            CommonDesignTokens.tabBorderRadius,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: FormDesignTokens.fieldLabelSize,
            fontWeight: FontWeight.w500,
            color: selected
                ? CommonDesignTokens.tabActiveText
                : CommonDesignTokens.tabInactiveText,
          ),
        ),
      ),
    );
  }

  static String _detailLabel(ExplanationDetail detail) {
    switch (detail) {
      case ExplanationDetail.brief:
        return 'Brief';
      case ExplanationDetail.balanced:
        return 'Balanced';
      case ExplanationDetail.detailed:
        return 'Detailed';
    }
  }

  Widget _buildInlineFieldRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
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
          ],
        ),
      ),
    );
  }

  void _saveConfig() {
    final config = AiLanguageConfig(
      model: _modelController.text.trim().isEmpty
          ? AiSettingsService.defaultModel
          : _modelController.text.trim(),
      detail: _detail,
      customPrompt: _promptController.text.trim(),
    );
    widget.onSave(config);
  }
}

// =============================================================================
// Section label
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: CommonDesignTokens.headerLabelSize,
        fontWeight: FontWeight.w600,
        color: CommonDesignTokens.headerLabelColor,
        letterSpacing: 0.5,
      ),
    );
  }
}
