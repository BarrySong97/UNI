import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/word-of-day/widgets/word_pronunciation_row.dart';
import 'package:uni/services/phonetics/phonetics_service.dart';
import 'package:uni/services/tts/tts_model_config.dart';
import 'package:uni/services/tts/tts_model_manager.dart';
import 'package:uni/services/tts/tts_service.dart';

void main() {
  testWidgets('shows IPA chips and plays selected accent', (tester) async {
    final phoneticsService = _FakePhoneticsService();
    final ttsService = _FakeTtsService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordPronunciationRow(
            selectedText: 'clarity',
            phoneticsService: phoneticsService,
            ttsService: ttsService,
          ),
        ),
      ),
    );
    await tester.pump();

    final padding = tester.widget<Padding>(find.byType(Padding).first);
    expect(padding.padding, EdgeInsets.zero);
    expect(
      find.byKey(const ValueKey<String>('word-pronunciation-us')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('word-pronunciation-uk')),
      findsOneWidget,
    );
    expect(find.text('/ˈklær.ə.t̬i/'), findsOneWidget);
    expect(find.text('/ˈklær.ə.ti/'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('word-pronunciation-uk')),
    );
    await tester.pump();

    expect(ttsService.lastText, 'clarity');
    expect(ttsService.lastLanguageCode, 'en_GB');
  });

  testWidgets('hides pronunciation row when no IPA exists', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordPronunciationRow(
            selectedText: 'clarity',
            phoneticsService: _EmptyPhoneticsService(),
            ttsService: _FakeTtsService(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('word-pronunciation-us')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('word-pronunciation-uk')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('word-pronunciation-ai')), findsNothing);
  });

  testWidgets('applies outer padding only when pronunciation is visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordPronunciationRow(
            selectedText: 'clarity',
            phoneticsService: _FakePhoneticsService(),
            ttsService: _FakeTtsService(),
            padding: const EdgeInsets.only(top: 12, bottom: 14),
          ),
        ),
      ),
    );
    await tester.pump();

    final padding = tester.widget<Padding>(find.byType(Padding).first);
    expect(padding.padding, const EdgeInsets.only(top: 12, bottom: 14));
  });

  testWidgets('shows AI button when local lookup misses but AI is supported', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WordPronunciationRow(
            selectedText: 'OpenAI',
            phoneticsService: _AiCapablePhoneticsService(),
            ttsService: _FakeTtsService(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('word-pronunciation-ai')), findsOneWidget);
  });
}

class _FakePhoneticsService extends PhoneticsService {
  @override
  Future<PhoneticsLookupOutcome> lookupWithOutcome(String text) async {
    return const PhoneticsLookupOutcome(
      result: PhoneticsResult(us: 'ˈklær.ə.t̬i', uk: 'ˈklær.ə.ti'),
      foundLocally: true,
      foundInAiCache: false,
      canTryAi: true,
    );
  }
}

class _EmptyPhoneticsService extends PhoneticsService {
  @override
  Future<PhoneticsLookupOutcome> lookupWithOutcome(String text) async {
    return const PhoneticsLookupOutcome(
      result: PhoneticsResult(us: '', uk: ''),
      foundLocally: false,
      foundInAiCache: false,
      canTryAi: false,
    );
  }
}

class _AiCapablePhoneticsService extends PhoneticsService {
  @override
  Future<PhoneticsLookupOutcome> lookupWithOutcome(String text) async {
    return const PhoneticsLookupOutcome(
      result: PhoneticsResult(us: '', uk: ''),
      foundLocally: false,
      foundInAiCache: false,
      canTryAi: true,
    );
  }
}

class _FakeTtsService extends TtsService {
  final _FakeTtsModelManager _fakeModelManager = _FakeTtsModelManager();

  String? lastText;
  String? lastLanguageCode;
  bool _isSpeaking = false;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  TtsModelManager get modelManager => _fakeModelManager;

  @override
  TtsModelInfo? modelInfoForLanguage(String languageCode) {
    return languageCode == 'en_GB'
        ? TtsBuiltinModels.ukModel
        : TtsBuiltinModels.usModel;
  }

  @override
  Future<void> speakWithLanguage(String text, String languageCode) async {
    lastText = text;
    lastLanguageCode = languageCode;
    _isSpeaking = true;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    _isSpeaking = false;
    notifyListeners();
  }
}

class _FakeTtsModelManager extends TtsModelManager {
  @override
  bool isReady(TtsModelInfo model) => true;
}
