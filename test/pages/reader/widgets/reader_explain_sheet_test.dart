import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni/pages/reader/widgets/reader_explain_sheet.dart';
import 'package:uni/services/ai/ai_settings_service.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/phonetics/phonetics_service.dart';
import 'package:uni/services/pos/pos_service.dart';
import 'package:uni/services/tts/tts_service.dart';

void main() {
  testWidgets('opening explain sheet does not auto-start TTS', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ai_auto_read_aloud': true,
    });

    final aiSettings = AiSettingsService();
    await aiSettings.initialize();
    final database = AppDatabase();
    const selectedText = 'This is a complete sentence. It should not autoplay.';
    await database.upsertExplainCache(
      bookId: 'book-1',
      chapterIndex: 0,
      selectedText: selectedText,
      contextSentence: '',
      response:
          '{"meaningExplain":"No automatic playback is started.","detailExplain":["Audio should only start from an explicit user action."]}',
    );
    final ttsService = _FakeTtsService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderExplainSheet(
            selectedText: selectedText,
            rawSelectedText: selectedText,
            pageContext: selectedText,
            paragraphContext: selectedText,
            aiSettings: aiSettings,
            languageConfig: const AiLanguageConfig(),
            bookTitle: 'Test Book',
            phoneticsService: _MissPhoneticsService(),
            posService: PosService(queryOverride: (_) async => null),
            ttsService: ttsService,
            database: database,
            bookId: 'book-1',
            chapterIndex: 0,
            bookLanguage: 'en',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(ttsService.bookLanguageSpeakCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _MissPhoneticsService extends PhoneticsService {
  @override
  Future<PhoneticsLookupOutcome> lookupWithOutcome(String text) async {
    return const PhoneticsLookupOutcome(
      result: PhoneticsResult.empty,
      foundLocally: false,
      foundInAiCache: false,
      canTryAi: false,
    );
  }
}

class _FakeTtsService extends TtsService {
  int bookLanguageSpeakCount = 0;

  @override
  bool get isSpeaking => false;

  @override
  Future<void> speakForBookLanguage(String text, String? bookLanguage) async {
    bookLanguageSpeakCount += 1;
  }

  @override
  Future<void> speakWithLanguage(String text, String languageCode) async {}

  @override
  Future<void> stop() async {}
}
