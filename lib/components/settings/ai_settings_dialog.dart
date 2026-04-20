import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app/providers/app-providers.dart';
import '../../services/ai/ai_settings_service.dart';
import '../../services/ai/explain_prompt_builder.dart';
import '../../services/ai/openai_llm_provider.dart';
import '../../services/search/image_search_service.dart';
import '../../services/tts/tts_service.dart';
import '../../services/tts/tts_voice_catalog.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/form-design-tokens.dart';
import '../../shared/constants/settings-design-tokens.dart';
import '../../shared/layout/responsive_layout.dart';
import '../../shared/widgets/english_pronunciation_selection_area.dart';

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

  /// Deduplicate configured languages by family (e.g. en_US + en_GB → one
  /// "English" entry). Keeps the first locale per family as the config key.
  List<String> _deduplicatedLanguages() {
    final all = widget.ttsService.configuredLanguages;
    final seenFamilies = <String>{};
    final result = <String>[];
    for (final lang in all) {
      final family = lang.split('_').first;
      if (seenFamilies.add(family)) {
        result.add(lang);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final configuredLanguages = _deduplicatedLanguages();

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

              // BEHAVIOR section
              const _SectionLabel(label: 'BEHAVIOR'),
              const SizedBox(height: 12),
              _buildCard(
                children: [
                  ListenableBuilder(
                    listenable: widget.aiSettings,
                    builder: (context, _) {
                      return SwitchListTile.adaptive(
                        title: const Text(
                          'Auto Read Aloud',
                          style: TextStyle(
                            fontSize: FormDesignTokens.fieldLabelSize,
                            fontWeight: FontWeight.w600,
                            color: CommonDesignTokens.textPrimary,
                          ),
                        ),
                        subtitle: const Text(
                          'Automatically read selected text aloud when explain sheet opens.',
                          style: TextStyle(
                            fontSize: FormDesignTokens.helperSize,
                            color: CommonDesignTokens.textSecondary,
                            height: FormDesignTokens.helperLineHeight,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        value: widget.aiSettings.autoReadAloud,
                        onChanged: (value) {
                          widget.aiSettings.setAutoReadAloud(value);
                        },
                      );
                    },
                  ),
                  _buildDivider(),
                  ListenableBuilder(
                    listenable: widget.aiSettings,
                    builder: (context, _) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: FormDesignTokens.fieldRowHeight,
                          child: Row(
                            children: [
                              Container(
                                width: SettingsDesignTokens
                                    .settingsRowIconContainerSize,
                                height: SettingsDesignTokens
                                    .settingsRowIconContainerSize,
                                decoration: BoxDecoration(
                                  color: SettingsDesignTokens
                                      .settingsRowIconContainerBg,
                                  borderRadius: BorderRadius.circular(
                                    SettingsDesignTokens
                                        .settingsRowIconContainerRadius,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_search_outlined,
                                  size: 20,
                                  color: CommonDesignTokens.headerLabelColor,
                                ),
                              ),
                              const SizedBox(
                                width: FormDesignTokens.fieldIconGap,
                              ),
                              const Text(
                                'Image Search',
                                style: TextStyle(
                                  fontSize: FormDesignTokens.fieldLabelSize,
                                  fontWeight: FontWeight.w500,
                                  color: CommonDesignTokens.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              DropdownButton<ImageSearchEngine>(
                                value: widget.aiSettings.imageSearchEngine,
                                underline: const SizedBox.shrink(),
                                style: const TextStyle(
                                  fontSize: FormDesignTokens.fieldValueSize,
                                  color: CommonDesignTokens.textPrimary,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: ImageSearchEngine.bing,
                                    child: Text('Bing'),
                                  ),
                                  DropdownMenuItem(
                                    value: ImageSearchEngine.google,
                                    child: Text('Google'),
                                  ),
                                  DropdownMenuItem(
                                    value: ImageSearchEngine.baidu,
                                    child: Text('Baidu'),
                                  ),
                                ],
                                onChanged: (engine) {
                                  if (engine != null) {
                                    widget.aiSettings.setImageSearchEngine(
                                      engine,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
    // Show just the language name (e.g. "English") without country.
    final langLabel = group?.languageName ?? languageCode;
    final config = widget.aiSettings.configForLanguage(languageCode);
    final hasCustomConfig = widget.aiSettings.configMap.containsKey(
      languageCode,
    );

    final subtitle = hasCustomConfig
        ? _configSummary(config, languageCode: languageCode)
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

  String _configSummary(
    AiLanguageConfig config, {
    required String languageCode,
  }) {
    final parts = <String>[config.model];
    parts.add(config.customPromptModeEnabled ? 'Custom Prompt' : 'Structured');
    parts.add(_detailLabel(config.detail));
    final vocabularyLabel = _vocabularyLabel(
      languageCode: languageCode,
      levelId: config.vocabularyLevel,
    );
    if (vocabularyLabel != null) {
      parts.add(vocabularyLabel);
    }
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

  static String? _vocabularyLabel({
    required String languageCode,
    required String levelId,
  }) {
    for (final option in AiSettingsService.vocabularyOptionsFor(languageCode)) {
      if (option.id == levelId) {
        return option.label;
      }
    }
    return null;
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
          aiSettings: widget.aiSettings,
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
    required this.aiSettings,
    required this.languageCode,
    required this.languageLabel,
    required this.config,
    required this.onSave,
    required this.onReset,
  });

  final AiSettingsService aiSettings;
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
  late bool _customPromptModeEnabled;
  late String _vocabularyLevel;

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(text: widget.config.model);
    _promptController = TextEditingController(text: widget.config.customPrompt);
    _detail = widget.config.detail;
    _customPromptModeEnabled = widget.config.customPromptModeEnabled;
    _vocabularyLevel = widget.config.vocabularyLevel.isNotEmpty
        ? widget.config.vocabularyLevel
        : AiSettingsService.defaultVocabularyLevelFor(widget.languageCode);
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

                  if (_showVocabularyLevelSection) ...[
                    const _SectionLabel(label: 'VOCABULARY LEVEL'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: CommonDesignTokens.tabGap,
                      runSpacing: CommonDesignTokens.tabGap,
                      children: [
                        for (final option in _vocabularyOptions)
                          _buildVocabularyLevelTab(option),
                      ],
                    ),
                    if (_selectedVocabularyOption != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          _selectedVocabularyOption!.description,
                          style: const TextStyle(
                            fontSize: FormDesignTokens.helperSize,
                            color: CommonDesignTokens.textSecondary,
                            height: FormDesignTokens.helperLineHeight,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],

                  const _SectionLabel(label: 'EXPLAIN MODE'),
                  const SizedBox(height: 8),
                  _buildCard(
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text(
                          'Enable custom prompt mode',
                          style: TextStyle(
                            fontSize: FormDesignTokens.fieldLabelSize,
                            fontWeight: FontWeight.w600,
                            color: CommonDesignTokens.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          _customPromptModeEnabled
                              ? 'Reader will render free-form markdown from your prompt.'
                              : 'Reader will use built-in structured explain cards.',
                          style: const TextStyle(
                            fontSize: FormDesignTokens.helperSize,
                            color: CommonDesignTokens.textSecondary,
                            height: FormDesignTokens.helperLineHeight,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        value: _customPromptModeEnabled,
                        onChanged: (value) {
                          setState(() => _customPromptModeEnabled = value);
                        },
                      ),
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
                      enabled: _customPromptModeEnabled,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontSize: FormDesignTokens.textareaSize,
                        color: CommonDesignTokens.textPrimary,
                        height: FormDesignTokens.textareaLineHeight,
                      ),
                      decoration: InputDecoration(
                        hintText: _customPromptModeEnabled
                            ? 'Leave empty to use default prompt...'
                            : 'Enable custom prompt mode to edit.',
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
                      'placeholders. This takes effect only when custom prompt mode is enabled.',
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
                    OutlinedButton(
                      onPressed: _showTestSheet,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CommonDesignTokens.textPrimary,
                        side: BorderSide(
                          color: CommonDesignTokens.textSecondary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            CommonDesignTokens.cardRadius,
                          ),
                        ),
                      ),
                      child: const Text('Test'),
                    ),
                    const SizedBox(width: 8),
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

  bool get _showVocabularyLevelSection {
    return AiSettingsService.isEnglishLanguageCode(widget.languageCode) &&
        _vocabularyOptions.isNotEmpty;
  }

  List<VocabularyLevelOption> get _vocabularyOptions {
    return AiSettingsService.vocabularyOptionsFor(widget.languageCode);
  }

  VocabularyLevelOption? get _selectedVocabularyOption {
    for (final option in _vocabularyOptions) {
      if (option.id == _vocabularyLevel) {
        return option;
      }
    }
    return _vocabularyOptions.isEmpty ? null : _vocabularyOptions.first;
  }

  Widget _buildVocabularyLevelTab(VocabularyLevelOption option) {
    final selected = _vocabularyLevel == option.id;
    return GestureDetector(
      onTap: () => setState(() => _vocabularyLevel = option.id),
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
          option.label,
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
      explanationLanguage: widget.config.explanationLanguage,
      customPrompt: _promptController.text.trim(),
      customPromptModeEnabled: _customPromptModeEnabled,
      vocabularyLevel: _showVocabularyLevelSection
          ? _vocabularyLevel
          : widget.config.vocabularyLevel,
    );
    widget.onSave(config);
  }

  void _showTestSheet() {
    if (!widget.aiSettings.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure your API key first.')),
      );
      return;
    }
    final model = _modelController.text.trim().isEmpty
        ? AiSettingsService.defaultModel
        : _modelController.text.trim();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TestExplainSheet(
        aiSettings: widget.aiSettings,
        languageCode: widget.languageCode,
        config: AiLanguageConfig(
          model: model,
          detail: _detail,
          explanationLanguage: widget.config.explanationLanguage,
          customPrompt: _promptController.text.trim(),
          customPromptModeEnabled: _customPromptModeEnabled,
          vocabularyLevel: _showVocabularyLevelSection
              ? _vocabularyLevel
              : widget.config.vocabularyLevel,
        ),
      ),
    );
  }
}

// =============================================================================
// Test explain sheet — mimics the Reader explain bottom sheet with sample data.
// =============================================================================

class _TestExplainSheet extends StatefulWidget {
  const _TestExplainSheet({
    required this.aiSettings,
    required this.languageCode,
    required this.config,
  });

  final AiSettingsService aiSettings;
  final String languageCode;
  final AiLanguageConfig config;

  static const _testBookTitle = 'The Great Gatsby';
  static const _testSelectedText = 'ephemeral';
  static const _testSentence =
      'Yet the sight made him feel that the moment was ephemeral, '
      'destined to dissolve like morning mist under the indifferent sun.';

  @override
  State<_TestExplainSheet> createState() => _TestExplainSheetState();
}

class _TestExplainSheetState extends State<_TestExplainSheet>
    with SingleTickerProviderStateMixin {
  late final ExplainAiService _aiService;
  late final AnimationController _shimmerController;
  final ScrollController _scrollController = ScrollController();
  String _aiResponse = '';
  bool _isStreaming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    final systemPrompt = buildExplainSystemPrompt(
      bookTitle: _TestExplainSheet._testBookTitle,
      selectedText: _TestExplainSheet._testSelectedText,
      context: _TestExplainSheet._testSentence,
      languageCode: widget.languageCode,
      config: widget.config,
      includePartOfSpeech: true,
    );

    _aiService = ExplainAiService(
      settings: widget.aiSettings,
      systemPrompt: systemPrompt,
      model: widget.config.model,
    );

    _fetchFromAi();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchFromAi() async {
    setState(() {
      _isStreaming = true;
      _error = null;
      _aiResponse = '';
    });
    try {
      await for (final chunk in _aiService.sendMessage(
        'What does "${_TestExplainSheet._testSelectedText}" mean here?',
      )) {
        if (!mounted) return;
        setState(() => _aiResponse += chunk);
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isStreaming = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Word header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        _TestExplainSheet._testSelectedText,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'TEST',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildSentenceWithBoldWord(
                  _TestExplainSheet._testSentence,
                  _TestExplainSheet._testSelectedText,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 24),
          ),
          // AI response
          Expanded(child: _buildResponseArea()),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  decoration: TextDecoration.none,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSentenceWithBoldWord(String sentence, String word) {
    final index = sentence.indexOf(word);
    if (index < 0) {
      return Text(
        sentence,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade700,
          height: 1.4,
          decoration: TextDecoration.none,
        ),
      );
    }

    final before = sentence.substring(0, index);
    final after = sentence.substring(index + word.length);

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade700,
          height: 1.4,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: word,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  Widget _buildResponseArea() {
    if (_aiResponse.isEmpty && _isStreaming) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildSkeleton(),
      );
    }

    final providers = AppProvidersScope.maybeOf(context);
    final markdownBody = MarkdownBody(
      data: _aiResponse,
      selectable: false,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          fontSize: 15,
          height: 1.5,
          color: Colors.black87,
          decoration: TextDecoration.none,
        ),
      ),
    );

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: providers != null
          ? EnglishPronunciationSelectionArea(
              phoneticsService: providers.phoneticsService,
              ttsService: providers.ttsService,
              child: markdownBody,
            )
          : MarkdownBody(
              data: _aiResponse,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black87,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
    );
  }

  Widget _buildSkeleton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final offset = _shimmerController.value * 2 - 0.5;
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFEBEBEB),
                Color(0xFFF5F5F5),
                Color(0xFFEBEBEB),
              ],
              stops: [
                (offset - 0.3).clamp(0.0, 1.0),
                offset.clamp(0.0, 1.0),
                (offset + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonLine(1.0),
          const SizedBox(height: 10),
          _skeletonLine(0.92),
          const SizedBox(height: 10),
          _skeletonLine(0.85),
          const SizedBox(height: 10),
          _skeletonLine(0.6),
        ],
      ),
    );
  }

  Widget _skeletonLine(double widthFraction) {
    return FractionallySizedBox(
      widthFactor: widthFraction,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
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
