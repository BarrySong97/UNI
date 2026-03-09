import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import 'flureadium_platform_interface.dart';

/// An implementation of [FlureadiumPlatform] that uses method channels.
class MethodChannelFlureadium extends FlureadiumPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  MethodChannel methodChannel = const MethodChannel(
    'dev.mulev.flureadium/main',
  );

  /// The event channel used to receive text Locator changes from the native platform.
  @visibleForTesting
  EventChannel textLocatorChannel = const EventChannel(
    'dev.mulev.flureadium/text-locator',
  );

  @visibleForTesting
  EventChannel timebasedStateChannel = const EventChannel(
    'dev.mulev.flureadium/timebased-state',
  );

  @visibleForTesting
  EventChannel errorEventChannel = const EventChannel(
    'dev.mulev.flureadium/error',
  );

  /// The event channel used to receive text Locator changes from the native platform.
  @visibleForTesting
  EventChannel readerStatusChannel = const EventChannel(
    'dev.mulev.flureadium/reader-status',
  );

  Stream<Locator>? _onTextLocatorChanged;

  Stream<ReadiumTimebasedState>? _onTimebasedPlayerStateChanged;

  Stream<ReadiumReaderStatus>? _onReaderStatusChanged;
  Stream<ReaderStatusEvent>? _onReaderStatusEvents;
  Stream<ReaderLocatorEvent>? _onTextLocatorEvents;

  Stream<ReadiumError>? _onErrorEvent;

  /// Fires whenever the Reader's current Locator changes.
  @override
  Stream<Locator> get onTextLocatorChanged {
    _onTextLocatorChanged ??= onTextLocatorEvents.map((event) => event.locator);
    return _onTextLocatorChanged!;
  }

  @override
  Stream<ReaderLocatorEvent> get onTextLocatorEvents {
    _onTextLocatorEvents ??= textLocatorChannel.receiveBroadcastStream().map((
      dynamic event,
    ) {
      if (event is String) {
        final locator = Locator.fromJson(
          json.decode(event) as Map<String, dynamic>,
        );
        return ReaderLocatorEvent(locator: locator!);
      }
      if (event is Map) {
        final map = event.cast<dynamic, dynamic>();
        final sessionId = map['sessionId'] as String?;
        final rawLocator = map['locator'];
        Locator? locator;
        if (rawLocator is String) {
          locator = Locator.fromJson(
            json.decode(rawLocator) as Map<String, dynamic>,
          );
        } else if (rawLocator is Map) {
          locator = Locator.fromJson(rawLocator.cast<String, dynamic>());
        }
        if (locator != null) {
          return ReaderLocatorEvent(locator: locator, sessionId: sessionId);
        }
      }
      throw StateError('Unsupported text locator event: $event');
    });
    return _onTextLocatorEvents!;
  }

  /// Fires whenever the TimebasedNavigator changes state
  @override
  Stream<ReadiumTimebasedState> get onTimebasedPlayerStateChanged {
    _onTimebasedPlayerStateChanged ??= timebasedStateChannel
        .receiveBroadcastStream()
        .map((dynamic event) {
          final state = ReadiumTimebasedState.fromJsonMap(
            json.decode(event) as Map<String, dynamic>,
          );
          return state;
        });
    return _onTimebasedPlayerStateChanged!;
  }

  @override
  Stream<ReadiumReaderStatus> get onReaderStatusChanged {
    _onReaderStatusChanged ??= onReaderStatusEvents.map(
      (event) => event.status,
    );
    return _onReaderStatusChanged!;
  }

  @override
  Stream<ReaderStatusEvent> get onReaderStatusEvents {
    _onReaderStatusEvents ??= readerStatusChannel.receiveBroadcastStream().map((
      dynamic event,
    ) {
      if (event is String) {
        final status = ReadiumReaderStatus.values.firstWhere(
          (e) => e.name == event,
        );
        return ReaderStatusEvent(status: status);
      }
      if (event is Map) {
        final map = event.cast<dynamic, dynamic>();
        final statusName = map['status'] as String;
        final status = ReadiumReaderStatus.values.firstWhere(
          (e) => e.name == statusName,
        );
        final sessionId = map['sessionId'] as String?;
        return ReaderStatusEvent(status: status, sessionId: sessionId);
      }
      throw StateError('Unsupported reader status event: $event');
    });
    return _onReaderStatusEvents!;
  }

  @override
  Stream<ReadiumError> get onErrorEvent {
    _onErrorEvent ??= errorEventChannel.receiveBroadcastStream().map((
      dynamic event,
    ) {
      final errorEvent = ReadiumError.fromJson(
        (event as Map).cast<String, dynamic>(),
      );
      return errorEvent;
    });
    return _onErrorEvent!;
  }

  @override
  Future<Publication> loadPublication(String pubUrl) async {
    final publicationString = await methodChannel
        .invokeMethod<String>('loadPublication', [pubUrl])
        .then<String>((dynamic result) => result);

    return Publication.fromJson(
      json.decode(publicationString) as Map<String, dynamic>,
    )!;
  }

  @override
  Future<void> setCustomHeaders(Map<String, String> headers) async {
    await methodChannel.invokeMethod<void>('setCustomHeaders', {
      'httpHeaders': headers,
    });
  }

  @override
  Future<Publication> openPublication(
    String pubUrl, {
    String? sessionId,
  }) async {
    Future<String> openLegacy() => methodChannel
        .invokeMethod<String>('openPublication', [pubUrl])
        .then<String>((dynamic result) => result);

    Future<String> openForSession() => methodChannel
        .invokeMethod<String>('openPublicationWithSession', <String, dynamic>{
          'pubUrl': pubUrl,
          'sessionId': sessionId,
        })
        .then<String>((dynamic result) => result);

    final publicationString = (sessionId == null || !Platform.isIOS)
        ? await openLegacy()
        : await openForSession().catchError((_) => openLegacy());
    return Publication.fromJson(
      json.decode(publicationString) as Map<String, dynamic>,
    )!;
  }

  @override
  Future<void> closePublication({String? sessionId}) async {
    if (sessionId == null || !Platform.isIOS) {
      await methodChannel.invokeMethod<void>('closePublication');
      return;
    }
    try {
      await methodChannel.invokeMethod<void>(
        'closePublicationForSession',
        <String, dynamic>{'sessionId': sessionId},
      );
    } on Object {
      await methodChannel.invokeMethod<void>('closePublication');
    }
  }

  @override
  Future<void> goLeft() async => await currentReaderWidget?.goLeft();

  @override
  Future<void> goRight() async => await currentReaderWidget?.goRight();

  @override
  Future<void> skipToNext() async => await currentReaderWidget?.skipToNext();

  @override
  Future<void> skipToPrevious() async =>
      await currentReaderWidget?.skipToPrevious();

  @override
  Future<bool> goToLocator(Locator locator, {String? sessionId}) async {
    if (sessionId == null || !Platform.isIOS) {
      return await methodChannel.invokeMethod<bool>('goToLocator', [
            locator.toJson(),
          ]) ??
          false;
    }
    try {
      return await methodChannel.invokeMethod<bool>('goToLocatorWithSession', [
            locator.toJson(),
            sessionId,
          ]) ??
          false;
    } on Object {
      return await methodChannel.invokeMethod<bool>('goToLocator', [
            locator.toJson(),
          ]) ??
          false;
    }
  }

  @override
  Future<void> setEPUBPreferences(EPUBPreferences preferences) async {
    defaultPreferences = preferences;
    await currentReaderWidget?.setEPUBPreferences(preferences);
  }

  @override
  Future<void> setNavigationConfig(ReaderNavigationConfig config) async {
    defaultNavigationConfig = config;
    await currentReaderWidget?.setNavigationConfig(config);
  }

  @override
  Future<void> applyDecorations(
    String id,
    List<ReaderDecoration> decorations,
  ) async => await currentReaderWidget?.applyDecorations(id, decorations);

  @override
  Future<void> ttsEnable(TTSPreferences? preferences) async =>
      await methodChannel.invokeMethod('ttsEnable', preferences?.toMap());

  @override
  Future<void> play(Locator? fromLocator) async =>
      await methodChannel.invokeMethod('play', [fromLocator?.toJson()]);

  @override
  Future<void> stop() async => await methodChannel.invokeMethod('stop');

  @override
  Future<void> pause() async => await methodChannel.invokeMethod('pause');

  @override
  Future<void> resume() async => await methodChannel.invokeMethod('resume');

  @override
  Future<void> next() async => await methodChannel.invokeMethod('next');

  @override
  Future<void> previous() async => await methodChannel.invokeMethod('previous');

  @override
  Future<void> setDecorationStyle(
    ReaderDecorationStyle? utteranceDecoration,
    ReaderDecorationStyle? rangeDecoration,
  ) => methodChannel.invokeMethod('setDecorationStyle', [
    utteranceDecoration?.toJson(),
    rangeDecoration?.toJson(),
  ]);

  @override
  Future<List<ReaderTTSVoice>> ttsGetAvailableVoices() async {
    final voicesStr = await methodChannel.invokeMethod<List<dynamic>>(
      'ttsGetAvailableVoices',
    );
    final voices =
        voicesStr
            ?.whereType<String>()
            .map<Map<String, dynamic>>(
              (str) => json.decode(str) as Map<String, dynamic>,
            )
            .map<ReaderTTSVoice>((map) => ReaderTTSVoice.fromJsonMap(map))
            .toList() ??
        <ReaderTTSVoice>[];
    return voices;
  }

  @override
  Future<void> ttsSetVoice(String voiceIdentifier, String? forLanguage) async {
    await methodChannel.invokeMethod('ttsSetVoice', [
      voiceIdentifier,
      forLanguage,
    ]);
  }

  @override
  Future<void> ttsSetPreferences(TTSPreferences preferences) =>
      methodChannel.invokeMethod('ttsSetPreferences', preferences.toMap());

  @override
  Future<String?> getLinkContent(final Link link) => methodChannel
      .invokeMethod<String>('getLinkContent', [jsonEncode(link.toJson())]);

  @override
  Future<void> audioEnable({AudioPreferences? prefs, Locator? fromLocator}) =>
      methodChannel.invokeMethod('audioEnable', [
        prefs?.toMap(),
        fromLocator?.toJson(),
      ]);

  @override
  Future<void> audioSetPreferences(AudioPreferences prefs) =>
      methodChannel.invokeMethod('audioSetPreferences', prefs.toMap());

  @override
  Future<void> audioSeekBy(Duration offset) =>
      methodChannel.invokeMethod('audioSeekBy', offset.inSeconds);

  @override
  Future<Uint8List?> renderFirstPage(
    String pubUrl, {
    int maxWidth = 600,
    int maxHeight = 800,
  }) async {
    final result = await methodChannel.invokeMethod<Uint8List>(
      'renderFirstPage',
      [pubUrl, maxWidth, maxHeight],
    );
    return result;
  }
}
