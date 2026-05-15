import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/components/settings/tts_test_page.dart';
import 'package:uni/services/tts/tts_service.dart';

void main() {
  testWidgets('uses selected language and input text for quick checks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ttsService = _FakeTtsService();

    await tester.pumpWidget(
      MaterialApp(home: TtsTestPage(ttsService: ttsService)),
    );

    expect(find.text('TTS Test'), findsOneWidget);
    expect(find.text('Quick pronunciation checks'), findsOneWidget);
    expect(find.text('American Voice'), findsOneWidget);
    expect(find.text('0.5x'), findsOneWidget);

    await tester.tap(find.text('British English'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'attached');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Speak'));
    await tester.tap(find.widgetWithText(FilledButton, 'Speak'));
    await tester.pump();

    expect(ttsService.lastText, 'attached');
    expect(ttsService.lastLanguageCode, 'en_GB');
    expect(ttsService.lastSpeed, closeTo(0.5, 1e-6));
    expect(find.widgetWithText(FilledButton, 'Speak Again'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Stop'), findsOneWidget);
  });

  testWidgets('quick sample chips replace the text and stop resets playback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ttsService = _FakeTtsService();

    await tester.pumpWidget(
      MaterialApp(home: TtsTestPage(ttsService: ttsService)),
    );

    await tester.tap(find.widgetWithText(ActionChip, 'apple'));
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, 'apple');

    await tester.drag(find.byType(Slider), const Offset(300, 0));
    await tester.pump();
    expect(find.text('1.5x'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Speak'));
    await tester.tap(find.widgetWithText(FilledButton, 'Speak'));
    await tester.pump();
    expect(ttsService.isSpeaking, isTrue);
    expect(ttsService.lastSpeed, closeTo(1.5, 1e-6));

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Stop'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Stop'));
    await tester.pump();
    expect(ttsService.isSpeaking, isFalse);
  });
}

class _FakeTtsService extends TtsService {
  String? lastText;
  String? lastLanguageCode;
  double? lastSpeed;
  bool _isSpeaking = false;

  @override
  List<String> get configuredLanguages => const <String>['en_US', 'en_GB'];

  @override
  String get defaultEnglishAccent => 'en_US';

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  String voiceDisplayName(String languageCode) {
    if (languageCode == 'en_GB') {
      return 'British Voice';
    }
    return 'American Voice';
  }

  @override
  Future<void> speakWithLanguage(String text, String languageCode) async {
    await speakWithLanguageOptions(text, languageCode, speed: 1.0, volume: 1.0);
  }

  @override
  Future<void> speakWithLanguageOptions(
    String text,
    String languageCode, {
    required double speed,
    required double volume,
  }) async {
    lastText = text;
    lastLanguageCode = languageCode;
    lastSpeed = speed;
    _isSpeaking = true;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    _isSpeaking = false;
    notifyListeners();
  }
}
