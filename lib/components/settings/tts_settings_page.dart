import 'package:flutter/material.dart';

import '../../services/tts/tts_model_config.dart';
import '../../services/tts/tts_model_manager.dart';
import '../../services/tts/tts_service.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/form-design-tokens.dart';
import '../../shared/constants/settings-design-tokens.dart';

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
  late int _usSpeakerId;
  late int _ukSpeakerId;
  late String _readAloudAccent;

  @override
  void initState() {
    super.initState();
    _speed = widget.ttsService.speed;
    _volume = widget.ttsService.volume;
    _usSpeakerId = widget.ttsService.usSpeakerId;
    _ukSpeakerId = widget.ttsService.ukSpeakerId;
    _readAloudAccent = widget.ttsService.readAloudAccent;
    widget.ttsService.modelManager.addListener(_onModelChange);
  }

  @override
  void dispose() {
    widget.ttsService.modelManager.removeListener(_onModelChange);
    super.dispose();
  }

  void _onModelChange() {
    if (mounted) setState(() {});
  }

  TtsModelManager get _mm => widget.ttsService.modelManager;

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
            // VOICE MODEL section
            const _SectionLabel(label: 'VOICE MODEL'),
            const SizedBox(height: 12),
            _buildCard(
              children: [
                _buildModelRow(TtsModels.usModel),
                _buildDivider(),
                _buildModelRow(TtsModels.ukModel),
                // US Speaker ID (only if US model has multiple speakers).
                if (_mm.isReady(TtsModels.usModel) &&
                    TtsModels.usModel.speakerCount > 1) ...[
                  _buildDivider(),
                  _buildSpeakerIdRow(
                    label: 'US Speaker',
                    value: _usSpeakerId,
                    max: TtsModels.usModel.speakerCount - 1,
                    onChanged: (v) => setState(() => _usSpeakerId = v),
                  ),
                ],
                // UK Speaker ID (only if UK model has multiple speakers).
                if (_mm.isReady(TtsModels.ukModel) &&
                    TtsModels.ukModel.speakerCount > 1) ...[
                  _buildDivider(),
                  _buildSpeakerIdRow(
                    label: 'UK Speaker',
                    value: _ukSpeakerId,
                    max: TtsModels.ukModel.speakerCount - 1,
                    onChanged: (v) => setState(() => _ukSpeakerId = v),
                  ),
                ],
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
                _buildDivider(),
                _buildAccentPickerRow(),
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
  // Model row
  // ---------------------------------------------------------------------------

  Widget _buildModelRow(TtsModelInfo model) {
    final state = _mm.stateOf(model);
    final accentLabel = model.accent == 'uk' ? 'UK' : 'US';

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
                    '$accentLabel Model',
                    style: const TextStyle(
                      fontSize: FormDesignTokens.fieldLabelSize,
                      fontWeight: FontWeight.w500,
                      color: CommonDesignTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    model.displayName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CommonDesignTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _buildModelStatusWidget(model, state),
          ],
        ),
      ),
    );
  }

  Widget _buildModelStatusWidget(TtsModelInfo model, TtsModelState state) {
    switch (state.status) {
      case TtsModelStatus.ready:
        return const Icon(
          Icons.check_circle,
          size: 22,
          color: Color(0xFF22C55E),
        );
      case TtsModelStatus.downloading:
        return SizedBox(
          width: 80,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 6,
                    backgroundColor: FormDesignTokens.dividerColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      CommonDesignTokens.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(state.progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
            ],
          ),
        );
      case TtsModelStatus.extracting:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 6),
            Text(
              'Extracting...',
              style: TextStyle(
                fontSize: 12,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
          ],
        );
      case TtsModelStatus.error:
        return GestureDetector(
          onTap: () => _mm.downloadModel(model),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 18, color: Colors.red),
              SizedBox(width: 4),
              Text(
                'Retry',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      case TtsModelStatus.notDownloaded:
        return GestureDetector(
          onTap: () => _mm.downloadModel(model),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CommonDesignTokens.textPrimary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.download_outlined,
                  size: 16,
                  color: CommonDesignTokens.cardBg,
                ),
                const SizedBox(width: 4),
                Text(
                  '${model.estimatedSizeMB} MB',
                  style: const TextStyle(
                    fontSize: 12,
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
  // Speaker ID row
  // ---------------------------------------------------------------------------

  Widget _buildSpeakerIdRow({
    required String label,
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
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
              child: const Icon(
                Icons.person_outlined,
                size: 20,
                color: CommonDesignTokens.headerLabelColor,
              ),
            ),
            const SizedBox(width: FormDesignTokens.fieldIconGap),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: FormDesignTokens.fieldLabelSize,
                  fontWeight: FontWeight.w500,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _showSpeakerIdPicker(label, value, max, onChanged),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#$value',
                    style: const TextStyle(
                      fontSize: FormDesignTokens.fieldValueSize,
                      color: CommonDesignTokens.textPrimary,
                      fontWeight: FontWeight.w500,
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
          ],
        ),
      ),
    );
  }

  void _showSpeakerIdPicker(
    String label,
    int current,
    int max,
    ValueChanged<int> onChanged,
  ) {
    final controller = TextEditingController(text: current.toString());
    showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '0 – $max',
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
      if (v != null && mounted) onChanged(v);
    });
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
  // Accent picker row
  // ---------------------------------------------------------------------------

  Widget _buildAccentPickerRow() {
    return GestureDetector(
      onTap: _showAccentPicker,
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
                  Icons.language_outlined,
                  size: 20,
                  color: CommonDesignTokens.headerLabelColor,
                ),
              ),
              const SizedBox(width: FormDesignTokens.fieldIconGap),
              const Text(
                'Read Aloud Accent',
                style: TextStyle(
                  fontSize: FormDesignTokens.fieldLabelSize,
                  fontWeight: FontWeight.w500,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                _readAloudAccent == 'uk' ? 'UK' : 'US',
                style: const TextStyle(
                  fontSize: FormDesignTokens.fieldValueSize,
                  color: CommonDesignTokens.textPrimary,
                  fontWeight: FontWeight.w500,
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

  void _showAccentPicker() {
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: CommonDesignTokens.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  'Read Aloud Accent',
                  style: TextStyle(
                    fontSize: CommonDesignTokens.bookTitleSize,
                    fontWeight: FontWeight.w700,
                    color: CommonDesignTokens.textPrimary,
                  ),
                ),
              ),
              ListTile(
                title: const Text('US (American English)'),
                trailing: _readAloudAccent == 'us'
                    ? const Icon(
                        Icons.check,
                        color: CommonDesignTokens.headerLabelColor,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop('us'),
              ),
              ListTile(
                title: const Text('UK (British English)'),
                trailing: _readAloudAccent == 'uk'
                    ? const Icon(
                        Icons.check,
                        color: CommonDesignTokens.headerLabelColor,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop('uk'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((selected) {
      if (selected != null && mounted) {
        setState(() => _readAloudAccent = selected);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _test() async {
    final model = TtsModels.forAccent(_readAloudAccent);
    if (!_mm.isReady(model)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please download the model first.')),
        );
      }
      return;
    }
    await widget.ttsService.update(
      speed: _speed,
      volume: _volume,
      usSpeakerId: _usSpeakerId,
      ukSpeakerId: _ukSpeakerId,
      readAloudAccent: _readAloudAccent,
    );
    await widget.ttsService.speak(
      'This is a test of the text-to-speech settings.',
    );
  }

  Future<void> _save() async {
    await widget.ttsService.update(
      speed: _speed,
      volume: _volume,
      usSpeakerId: _usSpeakerId,
      ukSpeakerId: _ukSpeakerId,
      readAloudAccent: _readAloudAccent,
    );
    if (mounted) Navigator.of(context).pop();
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
