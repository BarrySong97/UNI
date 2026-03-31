import 'package:flutter/material.dart';

import '../../services/tts/tts_model_config.dart';
import '../../services/tts/tts_model_manager.dart';
import '../../services/tts/tts_service.dart';
import '../../services/tts/tts_voice_catalog.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/form-design-tokens.dart';
import '../../shared/constants/settings-design-tokens.dart';
import '../../shared/layout/responsive_layout.dart';

class TtsSettingsPage extends StatefulWidget {
  const TtsSettingsPage({super.key, required this.ttsService});

  final TtsService ttsService;

  static void push(BuildContext context, TtsService ttsService) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TtsSettingsPage(ttsService: ttsService),
      ),
    );
  }

  @override
  State<TtsSettingsPage> createState() => _TtsSettingsPageState();
}

class _TtsSettingsPageState extends State<TtsSettingsPage> {
  late double _speed;
  late double _volume;
  String? _isPlayingLang;
  bool _isStartingPreview = false;

  static const _sampleTexts = <String, String>{
    'en_US': 'This is a test of the text-to-speech settings.',
    'en_GB': 'This is a test of the text-to-speech settings.',
    'zh_CN': '这是一段语音合成测试文本，用于测试中文朗读效果。',
    'fr_FR': 'Ceci est un test de la synthèse vocale.',
    'de_DE': 'Dies ist ein Test der Sprachsynthese-Einstellungen.',
    'es_ES': 'Esta es una prueba de la síntesis de voz.',
    'es_MX': 'Esta es una prueba de la síntesis de voz.',
    'ru_RU': 'Это тест настроек синтеза речи.',
    'pt_BR': 'Este é um teste das configurações de síntese de voz.',
    'it_IT': 'Questo è un test delle impostazioni di sintesi vocale.',
    'nl_NL': 'Dit is een test van de spraaksynthese-instellingen.',
    'pl_PL': 'To jest test ustawień syntezy mowy.',
    'uk_UA': 'Це тест налаштувань синтезу мовлення.',
    'cs_CZ': 'Toto je test nastavení syntézy řeči.',
    'da_DK': 'Dette er en test af talesyntese-indstillingerne.',
    'fi_FI': 'Tämä on puhesynteesiasetusten testi.',
    'el_GR': 'Αυτή είναι μια δοκιμή των ρυθμίσεων σύνθεσης ομιλίας.',
    'hu_HU': 'Ez a beszédszintézis beállítások tesztje.',
    'is_IS': 'Þetta er prufa á raddtækni stillingunum.',
    'ka_GE': 'ეს არის ტექსტიდან მეტყველების ტესტი.',
    'lb_LU': 'Dëst ass en Test vun de Sproochsynthese-Astellungen.',
    'no_NO': 'Dette er en test av talesyntese-innstillingene.',
    'ro_RO': 'Acesta este un test al setărilor de sinteză vocală.',
    'sk_SK': 'Toto je test nastavení syntézy reči.',
    'sl_SI': 'To je test nastavitev govorne sinteze.',
    'sr_RS': 'Ово је тест подешавања синтезе говора.',
    'sv_SE': 'Detta är ett test av talsyntsinställningarna.',
    'sw_CD': 'Hii ni jaribio la mipangilio ya usanisi wa hotuba.',
    'tr_TR': 'Bu, konuşma sentezi ayarlarının bir testidir.',
    'vi_VN': 'Đây là bài kiểm tra cài đặt tổng hợp giọng nói.',
    'ar_JO': 'هذا اختبار لإعدادات تحويل النص إلى كلام.',
    'bn_BD': 'এটি টেক্সট-টু-স্পিচ সেটিংসের একটি পরীক্ষা।',
    'ne_NP': 'यो पाठ-वाचन सेटिङ्सको परीक्षण हो।',
  };

  @override
  void initState() {
    super.initState();
    _speed = widget.ttsService.speed;
    _volume = widget.ttsService.volume;
    widget.ttsService.modelManager.addListener(_onModelChange);
    widget.ttsService.catalog.addListener(_onCatalogChange);
    widget.ttsService.addListener(_onServiceChange);
  }

  @override
  void dispose() {
    widget.ttsService.modelManager.removeListener(_onModelChange);
    widget.ttsService.catalog.removeListener(_onCatalogChange);
    widget.ttsService.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onModelChange() {
    if (mounted) setState(() {});
  }

  void _onCatalogChange() {
    if (mounted) setState(() {});
  }

  void _onServiceChange() {
    // Don't clear playing state during the stop-then-speak transition.
    if (!_isStartingPreview &&
        !widget.ttsService.isSpeaking &&
        _isPlayingLang != null) {
      _isPlayingLang = null;
    }
    if (mounted) setState(() {});
  }

  TtsModelManager get _mm => widget.ttsService.modelManager;
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
          'Text-to-Speech',
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
            // LANGUAGES section
            const _SectionLabel(label: 'LANGUAGES'),
            const SizedBox(height: 12),
            _buildCard(
              children: [
                for (int i = 0; i < configuredLanguages.length; i++) ...[
                  if (i > 0) _buildDivider(),
                  _buildLanguageRow(configuredLanguages[i]),
                ],
                // TODO: re-enable when supporting more languages.
                // if (configuredLanguages.isNotEmpty) _buildDivider(),
                // _buildAddLanguageRow(),
              ],
            ),
            const SizedBox(height: 28),

            // DEFAULT ACCENT section
            const _SectionLabel(label: 'DEFAULT ACCENT'),
            const SizedBox(height: 12),
            _buildCard(
              children: [
                _buildAccentOptionRow('en_US', 'American English'),
                _buildDivider(),
                _buildAccentOptionRow('en_GB', 'British English'),
              ],
            ),
            const SizedBox(height: 28),

            // PLAYBACK section
            const _SectionLabel(label: 'PLAYBACK'),
            const SizedBox(height: 12),
            _buildCard(
              children: [
                const SizedBox(height: 8),
                _buildSliderRow(
                  icon: Icons.speed_outlined,
                  label: 'Speed',
                  value: _speed,
                  min: 0.5,
                  max: 3.0,
                  displayValue: '${_speed.toStringAsFixed(1)}x',
                  onChanged: (v) => setState(() => _speed = v),
                ),
                _buildDivider(),
                _buildSliderRow(
                  icon: Icons.volume_up_outlined,
                  label: 'Volume',
                  value: _volume,
                  min: 0.0,
                  max: 1.0,
                  displayValue: '${(_volume * 100).round()}%',
                  onChanged: (v) => setState(() => _volume = v),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Save button
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
  // Card & Divider
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

  // ---------------------------------------------------------------------------
  // Default accent row
  // ---------------------------------------------------------------------------

  Widget _buildAccentOptionRow(String languageCode, String label) {
    final isSelected = widget.ttsService.defaultEnglishAccent == languageCode;
    return GestureDetector(
      onTap: () => widget.ttsService.setDefaultEnglishAccent(languageCode),
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
                  Icons.spatial_audio_off_outlined,
                  size: 20,
                  color: CommonDesignTokens.headerLabelColor,
                ),
              ),
              const SizedBox(width: FormDesignTokens.fieldIconGap),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: FormDesignTokens.fieldValueSize,
                    color: CommonDesignTokens.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check,
                  size: 20,
                  color: CommonDesignTokens.headerLabelColor,
                ),
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
    final voiceMap = widget.ttsService.voiceMap;
    final selection = voiceMap[languageCode];
    final modelInfo = widget.ttsService.modelInfoForLanguage(languageCode);
    final displayName = widget.ttsService.voiceDisplayName(languageCode);

    // Get language display name from catalog.
    final group = _catalog.languageGroups[languageCode];
    final langLabel = group?.displayLabel ?? languageCode;

    // Model status.
    final isReady = modelInfo != null && _mm.isReady(modelInfo);
    final state = modelInfo != null ? _mm.stateOf(modelInfo) : null;

    return GestureDetector(
      onTap: () => _showVoicePicker(languageCode),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  Icons.record_voice_over_outlined,
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
                      isReady
                          ? displayName
                          : selection != null
                              ? '$displayName — tap to download'
                              : 'Not selected — tap to configure',
                      style: TextStyle(
                        fontSize: 12,
                        color: isReady
                            ? CommonDesignTokens.textSecondary
                            : CommonDesignTokens.textSecondary
                                .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (selection != null) ...[
                _buildLanguageStatusWidget(modelInfo, state, isReady),
                const SizedBox(width: 4),
              ],
              if (isReady)
                GestureDetector(
                  onTap: () => _playLanguagePreview(languageCode),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      _isPlayingLang == languageCode &&
                              widget.ttsService.isSpeaking
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                      size: 24,
                      color: _isPlayingLang == languageCode &&
                              widget.ttsService.isSpeaking
                          ? CommonDesignTokens.textPrimary
                          : CommonDesignTokens.headerLabelColor,
                    ),
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

  Widget _buildLanguageStatusWidget(
    TtsModelInfo? modelInfo,
    TtsModelState? state,
    bool isReady,
  ) {
    if (state == null || modelInfo == null) {
      return const SizedBox.shrink();
    }
    switch (state.status) {
      case TtsModelStatus.ready:
        return const SizedBox.shrink();
      case TtsModelStatus.downloading:
        return SizedBox(
          width: 60,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 4,
                    backgroundColor: FormDesignTokens.dividerColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      CommonDesignTokens.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${(state.progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 10,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
            ],
          ),
        );
      case TtsModelStatus.extracting:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case TtsModelStatus.error:
        return GestureDetector(
          onTap: () => _mm.downloadModel(modelInfo),
          child: const Icon(Icons.error_outline, size: 18, color: Colors.red),
        );
      case TtsModelStatus.notDownloaded:
        return GestureDetector(
          onTap: () => _mm.downloadModel(modelInfo),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CommonDesignTokens.textPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.download_outlined,
                  size: 14,
                  color: CommonDesignTokens.cardBg,
                ),
                const SizedBox(width: 3),
                Text(
                  '${modelInfo.estimatedSizeMB} MB',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: CommonDesignTokens.cardBg,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Add language row
  // ---------------------------------------------------------------------------

  // TODO: re-enable when supporting more languages.
  // ignore: unused_element
  Widget _buildAddLanguageRow() {
    return GestureDetector(
      onTap: _showAddLanguagePicker,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          height: FormDesignTokens.fieldRowHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 20,
                color: CommonDesignTokens.headerLabelColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Add Language',
                style: TextStyle(
                  fontSize: FormDesignTokens.fieldLabelSize,
                  fontWeight: FontWeight.w500,
                  color: CommonDesignTokens.headerLabelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Slider row
  // ---------------------------------------------------------------------------

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          SizedBox(
            height: 36,
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
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: FormDesignTokens.fieldLabelSize,
                    fontWeight: FontWeight.w500,
                    color: CommonDesignTokens.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: FormDesignTokens.fieldValueSize,
                    color: CommonDesignTokens.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: CommonDesignTokens.textPrimary,
              inactiveTrackColor: FormDesignTokens.dividerColor,
              thumbColor: CommonDesignTokens.textPrimary,
              overlayColor: CommonDesignTokens.textPrimary.withValues(
                alpha: 0.1,
              ),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Add Language picker
  // ---------------------------------------------------------------------------

  void _showAddLanguagePicker() {
    final groups = _catalog.languageGroups;
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _catalog.isLoading
                ? 'Loading voice catalog...'
                : 'Voice catalog unavailable. Check your connection.',
          ),
        ),
      );
      if (!_catalog.isLoading) {
        _catalog.refresh();
      }
      return;
    }

    final configured = widget.ttsService.configuredLanguages.toSet();
    final available = groups.values
        .where((g) => !configured.contains(g.languageCode))
        .toList()
      ..sort((a, b) => a.displayLabel.compareTo(b.displayLabel));

    showModalBottomSheet<String>(
      context: context,
      backgroundColor: CommonDesignTokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => _AddLanguageSheet(available: available),
    ).then((languageCode) {
      if (languageCode != null && mounted) {
        // Add with the first available voice as default.
        final voices = _catalog.voicesForLanguage(languageCode);
        if (voices.isNotEmpty) {
          // Prefer medium quality.
          final preferred = voices.firstWhere(
            (v) => v.quality == 'medium',
            orElse: () => voices.first,
          );
          widget.ttsService.setVoiceForLanguage(
            languageCode,
            preferred.key,
          );
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Voice picker for a language
  // ---------------------------------------------------------------------------

  void _showVoicePicker(String languageCode) {
    final voices = _catalog.voicesForLanguage(languageCode);
    final group = _catalog.languageGroups[languageCode];
    final currentSelection = widget.ttsService.voiceMap[languageCode];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CommonDesignTokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return _VoicePickerSheet(
          languageCode: languageCode,
          languageLabel: group?.displayLabel ?? languageCode,
          voices: voices,
          currentVoiceKey: currentSelection?.voiceKey,
          currentSpeakerId: currentSelection?.speakerId ?? 0,
          modelManager: _mm,
          ttsService: widget.ttsService,
          onSelect: (voiceKey, speakerId) {
            widget.ttsService.setVoiceForLanguage(
              languageCode,
              voiceKey,
              speakerId: speakerId,
            );
            Navigator.of(ctx).pop();
          },
          onRemoveLanguage: () {
            widget.ttsService.removeLanguage(languageCode);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  String _sampleText(String languageCode) {
    if (_sampleTexts.containsKey(languageCode)) {
      return _sampleTexts[languageCode]!;
    }
    // Try language family fallback: "en_GB" -> "en_US".
    final family = languageCode.split('_').first;
    for (final entry in _sampleTexts.entries) {
      if (entry.key.startsWith('${family}_')) return entry.value;
    }
    return _sampleTexts['en_US']!;
  }

  Future<void> _playLanguagePreview(String languageCode) async {
    if (_isPlayingLang == languageCode && widget.ttsService.isSpeaking) {
      await widget.ttsService.stop();
      return;
    }
    await widget.ttsService.updatePlayback(speed: _speed, volume: _volume);
    _isStartingPreview = true;
    setState(() => _isPlayingLang = languageCode);
    try {
      await widget.ttsService.speakWithLanguage(
        _sampleText(languageCode),
        languageCode,
      );
    } finally {
      _isStartingPreview = false;
    }
  }

  Future<void> _save() async {
    await widget.ttsService.updatePlayback(speed: _speed, volume: _volume);
    if (mounted) Navigator.of(context).pop();
  }
}

// =============================================================================
// Voice Picker Bottom Sheet (StatefulWidget for gender filter)
// =============================================================================

class _VoicePickerSheet extends StatefulWidget {
  const _VoicePickerSheet({
    required this.languageCode,
    required this.languageLabel,
    required this.voices,
    required this.currentVoiceKey,
    required this.currentSpeakerId,
    required this.modelManager,
    required this.ttsService,
    required this.onSelect,
    required this.onRemoveLanguage,
  });

  final String languageCode;
  final String languageLabel;
  final List<TtsVoiceInfo> voices;
  final String? currentVoiceKey;
  final int currentSpeakerId;
  final TtsModelManager modelManager;
  final TtsService ttsService;
  final void Function(String voiceKey, int speakerId) onSelect;
  final VoidCallback onRemoveLanguage;

  @override
  State<_VoicePickerSheet> createState() => _VoicePickerSheetState();
}

class _VoicePickerSheetState extends State<_VoicePickerSheet> {
  VoiceGender? _genderFilter;
  late String? _selectedKey;
  late int _speakerId;
  String? _previewingKey;
  bool _isStartingPreview = false;

  @override
  void initState() {
    super.initState();
    _selectedKey = widget.currentVoiceKey;
    _speakerId = widget.currentSpeakerId;
    widget.modelManager.addListener(_onModelChange);
    widget.ttsService.addListener(_onTtsChange);
  }

  @override
  void dispose() {
    widget.modelManager.removeListener(_onModelChange);
    widget.ttsService.removeListener(_onTtsChange);
    super.dispose();
  }

  void _onModelChange() {
    if (mounted) setState(() {});
  }

  void _onTtsChange() {
    if (!_isStartingPreview &&
        !widget.ttsService.isSpeaking &&
        _previewingKey != null) {
      _previewingKey = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _previewVoice(TtsVoiceInfo voice, TtsModelInfo modelInfo) async {
    if (_previewingKey == voice.key && widget.ttsService.isSpeaking) {
      await widget.ttsService.stop();
      return;
    }
    _isStartingPreview = true;
    setState(() => _previewingKey = voice.key);
    final text = _TtsSettingsPageState._sampleTexts[widget.languageCode] ??
        _TtsSettingsPageState._sampleTexts['en_US']!;
    try {
      await widget.ttsService.previewVoice(
        text: text,
        model: modelInfo,
        speakerId: _selectedKey == voice.key ? _speakerId : 0,
      );
    } finally {
      _isStartingPreview = false;
    }
  }

  List<TtsVoiceInfo> get _filteredVoices {
    if (_genderFilter == null) return widget.voices;
    return widget.voices.where((v) => v.gender == _genderFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredVoices;
    final selectedVoice = _selectedKey != null
        ? widget.voices.where((v) => v.key == _selectedKey).firstOrNull
        : null;
    final showSpeakerId =
        selectedVoice != null && selectedVoice.numSpeakers > 1;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.85,
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
            // Gender filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _filterChip('All', null),
                  const SizedBox(width: 8),
                  _filterChip('Male', VoiceGender.male),
                  const SizedBox(width: 8),
                  _filterChip('Female', VoiceGender.female),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Voice list
            Expanded(
              child: RadioGroup<String>(
                groupValue: _selectedKey ?? '',
                onChanged: (v) {
                  setState(() {
                    _selectedKey = v;
                    _speakerId = 0;
                  });
                },
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (_, index) {
                    final voice = filtered[index];
                    final isSelected = voice.key == _selectedKey;
                    final modelInfo = TtsModelInfo.fromVoiceInfo(voice);
                    final isReady = widget.modelManager.isReady(modelInfo);
                    final state = widget.modelManager.stateOf(modelInfo);

                    final isPreviewing = _previewingKey == voice.key &&
                        widget.ttsService.isSpeaking;

                    return ListTile(
                      leading: Radio<String>(
                        value: voice.key,
                      ),
                      title: Text(
                        voice.displayName,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: CommonDesignTokens.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        _voiceSubtitle(voice),
                        style: const TextStyle(
                          fontSize: 12,
                          color: CommonDesignTokens.textSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isReady)
                            GestureDetector(
                              onTap: () =>
                                  _previewVoice(voice, modelInfo),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  isPreviewing
                                      ? Icons.stop_circle_outlined
                                      : Icons.play_circle_outline,
                                  size: 22,
                                  color: isPreviewing
                                      ? CommonDesignTokens.textPrimary
                                      : CommonDesignTokens.headerLabelColor,
                                ),
                              ),
                            ),
                          _buildVoiceTrailing(modelInfo, state, isReady),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _selectedKey = voice.key;
                          _speakerId = 0;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
            // Speaker ID row (if applicable)
            if (showSpeakerId) ...[
              Padding(
                padding: const EdgeInsets.only(
                    left: FormDesignTokens.dividerIndent),
                child: Container(
                  height: FormDesignTokens.dividerThickness,
                  color: FormDesignTokens.dividerColor,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outlined,
                      size: 20,
                      color: CommonDesignTokens.headerLabelColor,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Speaker ID',
                      style: TextStyle(
                        fontSize: FormDesignTokens.fieldLabelSize,
                        fontWeight: FontWeight.w500,
                        color: CommonDesignTokens.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showSpeakerIdPicker(
                          selectedVoice.numSpeakers - 1),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#$_speakerId',
                            style: const TextStyle(
                              fontSize: FormDesignTokens.fieldValueSize,
                              color: CommonDesignTokens.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: CommonDesignTokens.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Bottom buttons
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    // Remove language
                    TextButton(
                      onPressed: widget.onRemoveLanguage,
                      child: const Text(
                        'Remove',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    const Spacer(),
                    // Select
                    FilledButton(
                      onPressed: _selectedKey != null
                          ? () =>
                              widget.onSelect(_selectedKey!, _speakerId)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: FormDesignTokens.buttonBg,
                        foregroundColor: FormDesignTokens.buttonText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            CommonDesignTokens.cardRadius,
                          ),
                        ),
                      ),
                      child: const Text('Select'),
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

  Widget _filterChip(String label, VoiceGender? gender) {
    final isActive = _genderFilter == gender;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) {
        setState(() => _genderFilter = isActive ? null : gender);
      },
      selectedColor: CommonDesignTokens.textPrimary,
      labelStyle: TextStyle(
        color: isActive
            ? CommonDesignTokens.cardBg
            : CommonDesignTokens.textSecondary,
        fontSize: 13,
      ),
      backgroundColor: CommonDesignTokens.pageBackground,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  String _voiceSubtitle(TtsVoiceInfo voice) {
    final parts = <String>[];
    if (voice.gender != VoiceGender.unknown) {
      parts.add(voice.gender == VoiceGender.male ? 'Male' : 'Female');
    }
    if (voice.numSpeakers > 1) {
      parts.add('${voice.numSpeakers} speakers');
    }
    parts.add('~${voice.estimatedSizeMB} MB');
    return parts.join(' · ');
  }

  Widget _buildVoiceTrailing(
    TtsModelInfo modelInfo,
    TtsModelState state,
    bool isReady,
  ) {
    switch (state.status) {
      case TtsModelStatus.ready:
        return const Icon(
          Icons.check_circle,
          size: 20,
          color: Color(0xFF22C55E),
        );
      case TtsModelStatus.downloading:
        return SizedBox(
          width: 50,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 4,
                    backgroundColor: FormDesignTokens.dividerColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      CommonDesignTokens.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case TtsModelStatus.extracting:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case TtsModelStatus.error:
        return GestureDetector(
          onTap: () => widget.modelManager.downloadModel(modelInfo),
          child: const Icon(Icons.error_outline, size: 18, color: Colors.red),
        );
      case TtsModelStatus.notDownloaded:
        return GestureDetector(
          onTap: () => widget.modelManager.downloadModel(modelInfo),
          child: const Icon(
            Icons.download_outlined,
            size: 22,
            color: CommonDesignTokens.textSecondary,
          ),
        );
    }
  }

  void _showSpeakerIdPicker(int max) {
    final controller = TextEditingController(text: _speakerId.toString());
    showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Speaker ID'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '0 - $max',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim()) ?? 0;
              Navigator.of(ctx).pop(v.clamp(0, max));
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((v) {
      if (v != null && mounted) {
        setState(() => _speakerId = v);
      }
    });
  }
}

// =============================================================================
// Section label
// =============================================================================

// =============================================================================
// Add Language Bottom Sheet with search
// =============================================================================

class _AddLanguageSheet extends StatefulWidget {
  const _AddLanguageSheet({required this.available});

  final List<TtsLanguageGroup> available;

  @override
  State<_AddLanguageSheet> createState() => _AddLanguageSheetState();
}

class _AddLanguageSheetState extends State<_AddLanguageSheet> {
  String _query = '';

  List<TtsLanguageGroup> get _filtered {
    if (_query.isEmpty) return widget.available;
    final q = _query.toLowerCase();
    return widget.available.where((g) {
      return g.languageCode.toLowerCase().contains(q) ||
          g.languageName.toLowerCase().contains(q) ||
          g.countryName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
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
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Add Language',
                style: TextStyle(
                  fontSize: CommonDesignTokens.bookTitleSize,
                  fontWeight: FontWeight.w700,
                  color: CommonDesignTokens.textPrimary,
                ),
              ),
            ),
            // Search field.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: false,
                style: const TextStyle(
                  color: CommonDesignTokens.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search language or code...',
                  hintStyle: const TextStyle(
                    color: CommonDesignTokens.textSecondary,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: CommonDesignTokens.textSecondary,
                  ),
                  filled: true,
                  fillColor: CommonDesignTokens.textPrimary
                      .withValues(alpha: 0.06),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: filtered.length,
                itemBuilder: (_, index) {
                  final group = filtered[index];
                  return ListTile(
                    title: Text(
                      group.displayLabel,
                      style: const TextStyle(
                        color: CommonDesignTokens.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${group.voices.length} voice${group.voices.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CommonDesignTokens.textSecondary,
                      ),
                    ),
                    trailing: Text(
                      group.languageCode,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CommonDesignTokens.textSecondary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(group.languageCode);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
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
