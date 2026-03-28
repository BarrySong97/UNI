import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/onboarding/onboarding_voice_step.dart';
import 'package:uni/services/tts/tts_model_config.dart';
import 'package:uni/services/tts/tts_model_manager.dart';

class _FakeModelManager extends TtsModelManager {
  final Map<String, TtsModelState> _states = {};

  @override
  TtsModelState stateOf(TtsModelInfo model) {
    return _states[model.id] ?? const TtsModelState();
  }

  @override
  bool isReady(TtsModelInfo model) {
    return stateOf(model).status == TtsModelStatus.ready;
  }

  @override
  Future<void> downloadModel(TtsModelInfo model) async {
    _states[model.id] = const TtsModelState(status: TtsModelStatus.ready);
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'OnboardingVoiceStep builds without AppProvidersScope and selects voice after download',
    (tester) async {
      final manager = _FakeModelManager();
      final selected = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingVoiceStep(
            modelManager: manager,
            onVoiceSelected: (languageCode, voiceKey) async {
              selected.add('$languageCode:$voiceKey');
            },
            onContinue: () {},
            onSkip: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Download').first);
      await tester.pumpAndSettle();

      expect(selected, contains('en_US:${TtsBuiltinModels.usModel.id}'));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    },
  );
}
