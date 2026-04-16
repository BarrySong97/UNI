import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:uni/services/tts/tts_audio_player.dart';
import 'package:uni/services/tts/tts_engine.dart';
import 'package:uni/services/tts/tts_model_config.dart';
import 'package:uni/services/tts/tts_model_manager.dart';

void main() {
  late Directory tempDir;
  late FakeTtsAudioPlayer audioPlayer;
  late FakeTtsSynthesizer synthesizer;
  late List<Float32List> writtenSampleBatches;
  late TtsEngine engine;

  const model = TtsBuiltinModels.usModel;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tts-engine-test');
    audioPlayer = FakeTtsAudioPlayer();
    synthesizer = FakeTtsSynthesizer();
    writtenSampleBatches = <Float32List>[];
    engine = TtsEngine(
      modelManager: FakeTtsModelManager(),
      audioPlayer: audioPlayer,
      tempDirectoryProvider: () async => tempDir.path,
      bindingsInitializer: () {},
      waveWriter:
          ({
            required String filename,
            required Float32List samples,
            required int sampleRate,
          }) {
            final file = File(filename);
            file.createSync(recursive: true);
            writtenSampleBatches.add(Float32List.fromList(samples));
            file.writeAsBytesSync(<int>[
              82,
              73,
              70,
              70,
              ...samples.length.toString().codeUnits,
            ]);
          },
      synthesizerFactory: (_, _) => synthesizer,
    );
    await engine.initialize();
  });

  tearDown(() async {
    engine.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('speak uses a unique wav path for each utterance', () async {
    await engine.speak(text: 'apple', model: model);
    final firstPath = audioPlayer.playedPaths.single;

    await engine.stop();
    await engine.speak(text: 'apple', model: model);
    final secondPath = audioPlayer.playedPaths.last;

    expect(secondPath, isNot(firstPath));
    expect(p.basename(firstPath), 'tts_output_${model.id}_1.wav');
    expect(p.basename(secondPath), 'tts_output_${model.id}_2.wav');
  });

  test('stop deletes the active playback file', () async {
    await engine.speak(text: 'apple', model: model);
    final activePath = audioPlayer.playedPaths.single;

    expect(File(activePath).existsSync(), isTrue);
    expect(engine.isSpeaking, isTrue);

    await engine.stop();

    expect(File(activePath).existsSync(), isFalse);
    expect(engine.isSpeaking, isFalse);
    expect(audioPlayer.stopCallCount, 1);
  });

  test('playback completion deletes the active playback file', () async {
    await engine.speak(text: 'apple', model: model);
    final activePath = audioPlayer.playedPaths.single;

    expect(File(activePath).existsSync(), isTrue);

    audioPlayer.triggerComplete();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(File(activePath).existsSync(), isFalse);
    expect(engine.isSpeaking, isFalse);
  });

  test('dispose cleans up remaining engine owned files', () async {
    await engine.speak(text: 'apple', model: model);
    final activePath = audioPlayer.playedPaths.single;

    expect(File(activePath).existsSync(), isTrue);

    engine.dispose();

    expect(File(activePath).existsSync(), isFalse);
    expect(synthesizer.freeCallCount, 1);
    expect(audioPlayer.disposed, isTrue);
    expect(tempDir.listSync(), isEmpty);
  });

  test('repeated short utterances do not reuse filenames', () async {
    await engine.speak(text: 'apple', model: model);
    final firstBasename = p.basename(audioPlayer.playedPaths.single);

    await engine.stop();
    await engine.speak(text: 'book', model: model);
    final secondBasename = p.basename(audioPlayer.playedPaths.last);

    expect(firstBasename, isNot(secondBasename));
    expect(
      firstBasename,
      matches(RegExp(r'^tts_output_en_US-kokoro-bella_\d+\.wav$')),
    );
    expect(
      secondBasename,
      matches(RegExp(r'^tts_output_en_US-kokoro-bella_\d+\.wav$')),
    );
  });

  test('kokoro playback keeps generated audio unchanged', () async {
    await engine.speak(text: 'attached', model: model);

    final writtenSamples = writtenSampleBatches.single;
    expect(writtenSamples.length, 3);
    expect(writtenSamples[0], closeTo(0.1, 1e-6));
    expect(writtenSamples[1], closeTo(0.2, 1e-6));
    expect(writtenSamples[2], closeTo(0.3, 1e-6));
  });

  test('kokoro keeps short synthesis text unchanged', () async {
    await engine.speak(text: 'attached', model: model);

    expect(synthesizer.generatedTexts.single, 'attached');
    expect(synthesizer.generatedSpeakerIds.single, 0);
    expect(synthesizer.generatedSpeeds.single, closeTo(1.0, 1e-6));
  });

  test('uk kokoro voice keeps synthesis text unchanged', () async {
    await engine.speak(text: 'attached', model: TtsBuiltinModels.ukModel);

    expect(synthesizer.generatedTexts.single, 'attached');
    expect(synthesizer.generatedSpeakerIds.single, 0);
    expect(synthesizer.generatedSpeeds.single, closeTo(1.0, 1e-6));
  });

  test('long en_US text keeps synthesis text unchanged', () async {
    const longText =
        'This is a longer passage that should not receive the hidden prefix workaround because it exceeds the short pronunciation limit and should also avoid the added playback warmup at playback time.';

    await engine.speak(text: longText, model: model);

    expect(synthesizer.generatedTexts.single, longText);
    expect(synthesizer.generatedSpeakerIds.single, 0);
    expect(synthesizer.generatedSpeeds.single, closeTo(1.0, 1e-6));
    expect(writtenSampleBatches.single.length, 3);
  });
}

class FakeTtsAudioPlayer implements TtsAudioPlayer {
  final List<String> playedPaths = <String>[];
  VoidCallback? _onComplete;
  int stopCallCount = 0;
  bool disposed = false;

  @override
  Future<void> playFile(String path, {required double volume}) async {
    playedPaths.add(path);
  }

  @override
  Future<void> stop() async {
    stopCallCount += 1;
  }

  @override
  void setOnComplete(VoidCallback callback) {
    _onComplete = callback;
  }

  void triggerComplete() {
    _onComplete?.call();
  }

  @override
  void dispose() {
    disposed = true;
  }
}

class FakeTtsSynthesizer implements TtsSynthesizer {
  int freeCallCount = 0;
  final List<String> generatedTexts = <String>[];
  final List<int> generatedSpeakerIds = <int>[];
  final List<double> generatedSpeeds = <double>[];

  @override
  sherpa_onnx.GeneratedAudio generate({
    required String text,
    required int sid,
    required double speed,
  }) {
    generatedTexts.add(text);
    generatedSpeakerIds.add(sid);
    generatedSpeeds.add(speed);
    return sherpa_onnx.GeneratedAudio(
      samples: Float32List.fromList(const <double>[0.1, 0.2, 0.3]),
      sampleRate: 24000,
    );
  }

  @override
  void free() {
    freeCallCount += 1;
  }
}

class FakeTtsModelManager extends TtsModelManager {
  @override
  bool isReady(TtsModelInfo model) => true;

  @override
  String getModelPath(TtsModelInfo model) => '/tmp/${model.id}.onnx';

  @override
  String getTokensPath(TtsModelInfo model) => '/tmp/tokens.txt';

  @override
  String getDataDir(TtsModelInfo model) => '/tmp/espeak-ng-data';
}
