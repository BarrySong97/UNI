import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/reader/widgets/reader_phonetics_sheet.dart';
import 'package:uni/services/phonetics/phonetics_service.dart';
import 'package:uni/services/tts/tts_model_config.dart';
import 'package:uni/services/tts/tts_model_manager.dart';
import 'package:uni/services/tts/tts_service.dart';

void main() {
  testWidgets('shows AI button and pronounce action when IPA misses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderPhoneticsSheet(
            selectedText: 'OpenAI',
            phoneticsService: _MissPhoneticsService(),
            ttsService: _FakeTtsService(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Pronounce'), findsOneWidget);
    expect(find.byKey(const ValueKey('reader-phonetics-ai')), findsOneWidget);
  });
}

class _MissPhoneticsService extends PhoneticsService {
  @override
  Future<PhoneticsLookupOutcome> lookupWithOutcome(String text) async {
    return const PhoneticsLookupOutcome(
      result: PhoneticsResult.empty,
      foundLocally: false,
      foundInAiCache: false,
      canTryAi: true,
    );
  }
}

class _FakeTtsService extends TtsService {
  final _FakeTtsModelManager _fakeModelManager = _FakeTtsModelManager();

  @override
  TtsModelManager get modelManager => _fakeModelManager;

  @override
  TtsModelInfo? modelInfoForLanguage(String languageCode) =>
      TtsBuiltinModels.usModel;

  @override
  Future<void> speakWithLanguage(String text, String languageCode) async {}

  @override
  Future<void> warmUpDefaultEnglishAccent() async {}

  @override
  Future<void> stop() async {}
}

class _FakeTtsModelManager extends TtsModelManager {
  @override
  bool isReady(TtsModelInfo model) => true;
}
