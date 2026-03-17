import 'package:flutter/material.dart';

import '../../services/tts/tts_service.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/form-design-tokens.dart';
import '../../shared/constants/settings-design-tokens.dart';

/// Unique key for a voice: "locale|name".
String _voiceKey(Map<String, String> voice) =>
    '${voice['locale']}|${voice['name']}';

String _voiceKeyFrom(String? locale, String? name) {
  if (locale == null || name == null) return '';
  return '$locale|$name';
}

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
  late double _speechRate;
  late double _pitch;
  late double _volume;
  String? _voiceName;
  String? _voiceLocale;

  List<Map<String, String>> _voices = [];
  bool _loadingVoices = true;

  @override
  void initState() {
    super.initState();
    _speechRate = widget.ttsService.speechRate;
    _pitch = widget.ttsService.pitch;
    _volume = widget.ttsService.volume;
    _voiceName = widget.ttsService.voiceName;
    _voiceLocale = widget.ttsService.voiceLocale;
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final voices = await widget.ttsService.getVoices();
    if (mounted) {
      setState(() {
        _voices = voices;
        _loadingVoices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // VOICE section
            const _SectionLabel(label: 'VOICE'),
            const SizedBox(height: 12),
            _buildCard(
              children: [
                _buildVoiceRow(),
              ],
            ),
            const SizedBox(height: 28),

            // PLAYBACK section
            const _SectionLabel(label: 'PLAYBACK'),
            const SizedBox(height: 12),
            _buildCard(
              children: [
                _buildSliderRow(
                  icon: Icons.speed_outlined,
                  label: 'Speed',
                  value: _speechRate,
                  min: 0.0,
                  max: 1.0,
                  displayValue: '${(_speechRate * 2).toStringAsFixed(1)}x',
                  onChanged: (v) => setState(() => _speechRate = v),
                ),
                _buildDivider(),
                _buildSliderRow(
                  icon: Icons.tune_outlined,
                  label: 'Pitch',
                  value: _pitch,
                  min: 0.5,
                  max: 2.0,
                  displayValue: _pitch.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _pitch = v),
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

            // Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: FormDesignTokens.buttonHeight,
                    child: OutlinedButton(
                      onPressed: _test,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CommonDesignTokens.textPrimary,
                        side: const BorderSide(
                          color: CommonDesignTokens.textPrimary,
                        ),
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
                      child: const Text('Test'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
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
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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

  Widget _buildVoiceRow() {
    return GestureDetector(
      onTap: _loadingVoices ? null : _showVoicePicker,
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
                  Icons.record_voice_over_outlined,
                  size: 20,
                  color: CommonDesignTokens.headerLabelColor,
                ),
              ),
              const SizedBox(width: FormDesignTokens.fieldIconGap),
              const Text(
                'Voice',
                style: TextStyle(
                  fontSize: FormDesignTokens.fieldLabelSize,
                  fontWeight: FontWeight.w500,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
              const Spacer(),
              if (_loadingVoices)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Flexible(
                  child: Text(
                    _voiceName != null
                        ? TtsService.parseDisplayName(_voiceName!)
                        : 'Default',
                    style: const TextStyle(
                      fontSize: FormDesignTokens.fieldValueSize,
                      color: CommonDesignTokens.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(width: 4),
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
              overlayColor:
                  CommonDesignTokens.textPrimary.withValues(alpha: 0.1),
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

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: FormDesignTokens.dividerIndent),
      child: Container(
        height: FormDesignTokens.dividerThickness,
        color: FormDesignTokens.dividerColor,
      ),
    );
  }

  void _showVoicePicker() {
    showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CommonDesignTokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _VoicePickerSheet(
        voices: _voices,
        selectedKey: _voiceKeyFrom(_voiceLocale, _voiceName),
        ttsService: widget.ttsService,
        speechRate: _speechRate,
        pitch: _pitch,
        volume: _volume,
      ),
    ).then((selected) {
      if (selected != null && mounted) {
        setState(() {
          _voiceName = selected['name'];
          _voiceLocale = selected['locale'];
        });
      }
    });
  }

  Future<void> _test() async {
    await widget.ttsService.update(
      speechRate: _speechRate,
      pitch: _pitch,
      volume: _volume,
      voiceName: _voiceName,
      voiceLocale: _voiceLocale,
    );
    await widget.ttsService.speak(
      'This is a test of the text-to-speech settings.',
    );
  }

  Future<void> _save() async {
    await widget.ttsService.update(
      speechRate: _speechRate,
      pitch: _pitch,
      volume: _volume,
      voiceName: _voiceName,
      voiceLocale: _voiceLocale,
    );
    if (mounted) Navigator.of(context).pop();
  }
}

/// Voice picker bottom sheet with preview playback and icon state.
class _VoicePickerSheet extends StatefulWidget {
  const _VoicePickerSheet({
    required this.voices,
    required this.selectedKey,
    required this.ttsService,
    required this.speechRate,
    required this.pitch,
    required this.volume,
  });

  final List<Map<String, String>> voices;
  final String selectedKey;
  final TtsService ttsService;
  final double speechRate;
  final double pitch;
  final double volume;

  @override
  State<_VoicePickerSheet> createState() => _VoicePickerSheetState();
}

class _VoicePickerSheetState extends State<_VoicePickerSheet> {
  String? _previewingKey;
  String? _selectedLanguage; // null means "All"
  late final List<String> _languages;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.ttsService.addListener(_onTtsStateChanged);

    // Extract unique language codes (e.g. "en", "zh", "ja") from locales,
    // sorted alphabetically, with the selected voice's language first.
    final langSet = <String>{};
    for (final v in widget.voices) {
      final locale = v['locale'] ?? '';
      final lang = locale.split('-').first.split('_').first;
      if (lang.isNotEmpty) langSet.add(lang);
    }
    _languages = langSet.toList()..sort();

    // Auto-select the language of the currently chosen voice.
    if (widget.selectedKey.isNotEmpty) {
      final selectedVoice = widget.voices.where(
        (v) => _voiceKey(v) == widget.selectedKey,
      );
      if (selectedVoice.isNotEmpty) {
        final locale = selectedVoice.first['locale'] ?? '';
        final lang = locale.split('-').first.split('_').first;
        if (lang.isNotEmpty) _selectedLanguage = lang;
      }
    }
  }

  List<Map<String, String>> get _filteredVoices {
    final query = _searchQuery.toLowerCase();
    return widget.voices.where((v) {
      // Language filter.
      if (_selectedLanguage != null) {
        final locale = v['locale'] ?? '';
        final lang = locale.split('-').first.split('_').first;
        if (lang != _selectedLanguage) return false;
      }
      // Search filter.
      if (query.isNotEmpty) {
        final name = (v['displayName'] ?? v['name'] ?? '').toLowerCase();
        final locale = (v['locale'] ?? '').toLowerCase();
        if (!name.contains(query) && !locale.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    widget.ttsService.removeListener(_onTtsStateChanged);
    super.dispose();
  }

  void _onTtsStateChanged() {
    if (!widget.ttsService.isSpeaking && _previewingKey != null) {
      if (mounted) setState(() => _previewingKey = null);
    }
  }

  Widget _buildLanguageChip(String? language, String label) {
    final isActive = _selectedLanguage == language;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedLanguage = language),
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isActive
                ? CommonDesignTokens.textPrimary
                : CommonDesignTokens.textPrimary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              height: 1.0,
              fontWeight: FontWeight.w500,
              color: isActive
                  ? CommonDesignTokens.cardBg
                  : CommonDesignTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _preview(Map<String, String> voice) async {
    final key = _voiceKey(voice);

    // Tap again to stop.
    if (_previewingKey == key && widget.ttsService.isSpeaking) {
      await widget.ttsService.stop();
      return;
    }

    await widget.ttsService.stop();
    setState(() => _previewingKey = key);

    await widget.ttsService.update(
      speechRate: widget.speechRate,
      pitch: widget.pitch,
      volume: widget.volume,
      voiceName: voice['name'],
      voiceLocale: voice['locale'],
    );
    await widget.ttsService.speak('Hello, this is a preview of this voice.');
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
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
                'Select Voice',
                style: TextStyle(
                  fontSize: CommonDesignTokens.bookTitleSize,
                  fontWeight: FontWeight.w700,
                  color: CommonDesignTokens.textPrimary,
                ),
              ),
            ),
            // Language filter chips.
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildLanguageChip(null, 'All'),
                  for (final lang in _languages)
                    _buildLanguageChip(lang, lang.toUpperCase()),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Search bar.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 38,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(
                    fontSize: 14,
                    color: CommonDesignTokens.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search voice...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: CommonDesignTokens.textSecondary
                          .withValues(alpha: 0.6),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: CommonDesignTokens.textSecondary,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                    ),
                    filled: true,
                    fillColor:
                        CommonDesignTokens.textPrimary.withValues(alpha: 0.04),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filteredVoices.length,
                itemBuilder: (context, index) {
                  final voice = _filteredVoices[index];
                  final key = _voiceKey(voice);
                  final isSelected = key == widget.selectedKey;
                  final isPreviewing = key == _previewingKey &&
                      widget.ttsService.isSpeaking;

                  final displayName = voice['displayName'] ?? voice['name']!;
                  final quality = voice['quality'] ?? 'default';

                  return ListTile(
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: FormDesignTokens.fieldValueSize,
                              color: CommonDesignTokens.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (quality == 'enhanced' || quality == 'premium') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              quality == 'premium' ? 'Premium' : 'Enhanced',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF22C55E),
                              ),
                            ),
                          ),
                        ] else if (quality == 'compact') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: CommonDesignTokens.textSecondary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Compact',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: CommonDesignTokens.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      voice['locale']!,
                      style: const TextStyle(
                        fontSize: FormDesignTokens.helperSize,
                        color: CommonDesignTokens.textSecondary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _preview(voice),
                          child: Icon(
                            isPreviewing
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline,
                            size: 24,
                            color: isPreviewing
                                ? CommonDesignTokens.textPrimary
                                : CommonDesignTokens.headerLabelColor,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.check,
                            color: CommonDesignTokens.headerLabelColor,
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      widget.ttsService.stop();
                      Navigator.of(context).pop(voice);
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
