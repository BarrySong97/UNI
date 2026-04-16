import 'package:flutter/material.dart';

import '../../services/tts/tts_service.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/form-design-tokens.dart';
import '../../shared/layout/responsive_layout.dart';
import 'settings-row.dart';

class TtsTestPage extends StatefulWidget {
  const TtsTestPage({super.key, required this.ttsService});

  final TtsService ttsService;

  static void push(BuildContext context, TtsService ttsService) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TtsTestPage(ttsService: ttsService),
      ),
    );
  }

  @override
  State<TtsTestPage> createState() => _TtsTestPageState();
}

class _TtsTestPageState extends State<TtsTestPage> {
  static const List<String> _quickSamples = <String>[
    'attached',
    'apple',
    'about',
    'absolutely',
    'a book',
    'at all',
  ];
  static const double _minimumTestSpeed = 0.5;
  static const double _maximumTestSpeed = 1.5;

  late final TextEditingController _textController;
  late double _testSpeed;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _quickSamples.first);
    _testSpeed = _minimumTestSpeed;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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
          'TTS Test',
          style: TextStyle(
            fontSize: CommonDesignTokens.bookTitleSize,
            fontWeight: FontWeight.w700,
            color: CommonDesignTokens.textPrimary,
          ),
        ),
      ),
      body: ResponsiveContentWrapper(
        child: ListenableBuilder(
          listenable: widget.ttsService,
          builder: (context, _) {
            final configuredLanguages = _configuredLanguages;
            final selectedLanguageCode = _selectedLanguageCode(
              configuredLanguages,
            );
            final hasConfiguredLanguages = configuredLanguages.isNotEmpty;
            final trimmedText = _textController.text.trim();
            final canSpeak = hasConfiguredLanguages && trimmedText.isNotEmpty;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SectionIntro(
                    title: 'Quick pronunciation checks',
                    description:
                        'Use the same shared TTS pipeline as Reader without '
                        'opening a book first.',
                  ),
                  const SizedBox(height: 24),
                  const SettingsSectionLabel(label: 'VOICE'),
                  const SizedBox(height: 12),
                  _buildCard(
                    child: hasConfiguredLanguages
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: configuredLanguages.map((
                                  languageCode,
                                ) {
                                  return ChoiceChip(
                                    label: Text(_languageLabel(languageCode)),
                                    selected:
                                        languageCode == selectedLanguageCode,
                                    onSelected: (_) {
                                      setState(() {
                                        _manualLanguageCode = languageCode;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Current voice',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: CommonDesignTokens.textSecondary
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.ttsService.voiceDisplayName(
                                  selectedLanguageCode,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CommonDesignTokens.textPrimary,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Configure at least one voice in Text-to-Speech '
                            'settings before using this page.',
                            style: TextStyle(
                              fontSize: 14,
                              color: CommonDesignTokens.textSecondary,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  const SettingsSectionLabel(label: 'TEXT'),
                  const SizedBox(height: 12),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TextField(
                          controller: _textController,
                          onChanged: (_) => setState(() {}),
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Type a word or short phrase',
                            filled: true,
                            fillColor: CommonDesignTokens.pageBackground,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                CommonDesignTokens.cardRadius,
                              ),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _quickSamples.map((sample) {
                            return ActionChip(
                              label: Text(sample),
                              onPressed: () => _replaceText(sample),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SettingsSectionLabel(label: 'SPEED'),
                  const SizedBox(height: 12),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.speed_outlined,
                              size: 18,
                              color: CommonDesignTokens.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Test speed',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: CommonDesignTokens.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_testSpeed.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                fontSize: 14,
                                color: CommonDesignTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: _testSpeed,
                          min: _minimumTestSpeed,
                          max: _maximumTestSpeed,
                          divisions:
                              ((_maximumTestSpeed - _minimumTestSpeed) / 0.1)
                                  .round(),
                          label: '${_testSpeed.toStringAsFixed(1)}x',
                          onChanged: (value) {
                            setState(() {
                              _testSpeed = value;
                            });
                          },
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Defaults to the slowest speed so you can hear '
                          'whether the first sound is actually generated.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: CommonDesignTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SettingsSectionLabel(label: 'ACTIONS'),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: canSpeak ? _speak : null,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            widget.ttsService.isSpeaking
                                ? 'Speak Again'
                                : 'Speak',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              FormDesignTokens.buttonHeight,
                            ),
                            backgroundColor: CommonDesignTokens.textPrimary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.ttsService.isSpeaking
                              ? _stop
                              : null,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Stop'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              FormDesignTokens.buttonHeight,
                            ),
                            foregroundColor: CommonDesignTokens.textPrimary,
                            side: const BorderSide(
                              color: CommonDesignTokens.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String? _manualLanguageCode;

  List<String> get _configuredLanguages {
    final configuredLanguages = widget.ttsService.configuredLanguages.toList()
      ..sort((a, b) {
        if (a == widget.ttsService.defaultEnglishAccent) {
          return -1;
        }
        if (b == widget.ttsService.defaultEnglishAccent) {
          return 1;
        }
        return a.compareTo(b);
      });
    return configuredLanguages;
  }

  String _selectedLanguageCode(List<String> configuredLanguages) {
    final manualLanguageCode = _manualLanguageCode;
    if (manualLanguageCode != null &&
        configuredLanguages.contains(manualLanguageCode)) {
      return manualLanguageCode;
    }
    final defaultAccent = widget.ttsService.defaultEnglishAccent;
    if (configuredLanguages.contains(defaultAccent)) {
      return defaultAccent;
    }
    if (configuredLanguages.isNotEmpty) {
      return configuredLanguages.first;
    }
    return defaultAccent;
  }

  Future<void> _speak() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final configuredLanguages = _configuredLanguages;
    if (configuredLanguages.isEmpty) {
      return;
    }

    await widget.ttsService.speakWithLanguageOptions(
      text,
      _selectedLanguageCode(configuredLanguages),
      speed: _testSpeed,
      volume: widget.ttsService.volume,
    );
  }

  Future<void> _stop() async {
    await widget.ttsService.stop();
  }

  void _replaceText(String sample) {
    _textController.value = TextEditingValue(
      text: sample,
      selection: TextSelection.collapsed(offset: sample.length),
    );
    setState(() {});
  }

  String _languageLabel(String languageCode) {
    switch (languageCode) {
      case 'en_US':
        return 'American English';
      case 'en_GB':
        return 'British English';
      default:
        return languageCode.replaceAll('_', '-');
    }
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: child,
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: CommonDesignTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: CommonDesignTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
