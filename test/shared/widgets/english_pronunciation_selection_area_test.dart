import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/phonetics/phonetics_service.dart';
import 'package:uni/services/tts/tts_model_config.dart';
import 'package:uni/services/tts/tts_model_manager.dart';
import 'package:uni/services/tts/tts_service.dart';
import 'package:uni/shared/widgets/english_pronunciation_selection_area.dart';

void main() {
  testWidgets('wraps child in SelectionArea when enabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EnglishPronunciationSelectionArea(
            phoneticsService: _FakePhoneticsService(),
            ttsService: _FakeTtsService(),
            child: const Text('ephemeral'),
          ),
        ),
      ),
    );

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.text('ephemeral'), findsOneWidget);
  });

  testWidgets('returns plain child when disabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EnglishPronunciationSelectionArea(
            enabled: false,
            phoneticsService: _FakePhoneticsService(),
            ttsService: _FakeTtsService(),
            child: const Text('ephemeral'),
          ),
        ),
      ),
    );

    expect(find.byType(SelectionArea), findsNothing);
    expect(find.text('ephemeral'), findsOneWidget);
  });
}

class _FakePhoneticsService extends PhoneticsService {
  @override
  Future<PhoneticsLookupOutcome> lookupWithOutcome(String text) async {
    return const PhoneticsLookupOutcome(
      result: PhoneticsResult(us: 'ɪˈfem.ə.rəl', uk: 'ɪˈfem.ə.rəl'),
      foundLocally: true,
      foundInAiCache: false,
      canTryAi: true,
    );
  }
}

class _FakeTtsService extends TtsService {
  final _FakeTtsModelManager _fakeModelManager = _FakeTtsModelManager();

  @override
  String get defaultEnglishAccent => 'en_US';

  @override
  TtsModelManager get modelManager => _fakeModelManager;

  @override
  TtsModelInfo? modelInfoForLanguage(String languageCode) =>
      TtsBuiltinModels.usModel;

  @override
  Future<void> speakWithLanguage(String text, String languageCode) async {}

  @override
  Future<void> warmUpLanguage(String languageCode) async {}

  @override
  Future<void> stop() async {}
}

class _FakeTtsModelManager extends TtsModelManager {
  @override
  bool isReady(TtsModelInfo model) => true;
}
