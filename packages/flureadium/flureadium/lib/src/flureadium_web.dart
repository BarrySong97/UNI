import 'dart:convert';
import 'package:flureadium_platform_interface/flureadium_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'js_publication_channel.dart';
import 'package:flutter/services.dart';
import 'web/json_transformer.dart';
import 'web/web_stream_handlers.dart';

class FlureadiumWebPlugin extends FlureadiumPlatform {
  static void registerWith(Registrar registrar) {
    FlureadiumPlatform.instance = FlureadiumWebPlugin();
  }

  static void addTextLocatorUpdate(Locator locator) {
    WebStreamHandlers.addTextLocatorUpdate(locator);
  }

  static void addTimeBasedStateUpdate(ReadiumTimebasedState timebasedState) {
    WebStreamHandlers.addTimeBasedStateUpdate(timebasedState);
  }

  static void addReaderStatusUpdate(ReadiumReaderStatus status) {
    WebStreamHandlers.addReaderStatusUpdate(status);
  }

  @override
  Stream<Locator> get onTextLocatorChanged {
    return WebStreamHandlers.onTextLocatorChanged;
  }

  @override
  Stream<ReadiumTimebasedState> get onTimebasedPlayerStateChanged {
    return WebStreamHandlers.onTimebasedPlayerStateChanged;
  }

  @override
  Stream<ReadiumReaderStatus> get onReaderStatusChanged {
    return WebStreamHandlers.onReaderStatusChanged;
  }

  @override
  Future<void> setCustomHeaders(Map<String, String> headers) async {
    R2Log.d('setCustomHeaders is not implemented on web platform');
  }

  @override
  void setDefaultPreferences(EPUBPreferences preferences) {
    defaultPreferences = preferences;
  }

  @override
  Future<Publication> loadPublication(String pubUrl) async {
    Publication? publication;

    try {
      final publicationString = await JsPublicationChannel().getPublication(
        pubUrl,
      );

      var publicationJson =
          jsonDecode(publicationString) as Map<String, dynamic>;

      publicationJson = PublicationJsonTransformer.transform(publicationJson);

      publication = Publication.fromJson(publicationJson);
      if (publication == null) {
        throw ReadiumError('Failed to parse Publication JSON');
      }
    } on PlatformException catch (e) {
      final type = e.intCode;
      throw OpeningReadiumException(
        '${e.code}: ${e.message ?? 'Unknown `PlatformException`'}',
        type: type == null ? null : OpeningReadiumExceptionType.values[type],
      );
    } on Error catch (e) {
      final eString = e.toString();
      throw ReadiumError('Error in PublicationChannel web: $eString');
    } on Exception catch (e) {
      final eString = e.toString();
      throw ReadiumError('Exception in PublicationChannel web: $eString');
    }

    return publication;
  }

  @override
  Future<Publication> openPublication(String pubUrl) async {
    // NOTE: For web, loadPublication and openPublication does the same thing,
    //
    // If calling the openPublication method outside of ReadiumWebView it will throw an error right away if there is no div with the id 'container'
    // additionally the openPublication method does currently not return a publication object
    R2Log.d(
      'Cannot call openPublication outside of ReadiumWebView on web. Using getPublication instead to fetch the publication data.',
    );
    final publication = await loadPublication(pubUrl);
    return publication;
  }

  @override
  Future<void> closePublication() async {
    JsPublicationChannel().closePublication();
    return;
  }

  @override
  Future<String?> getLinkContent(Link link) {
    return getString(link);
  }

  static Future<String> getString(final Link link) async {
    // Get HTML string for full chapters, for example
    final linkString = json.encode(link);
    final resourceString = await JsPublicationChannel().getResource(linkString);
    return resourceString;
  }

  static Future<Uint8List> getBytes(final Link link) async {
    // TODO: Is this still needed for audio books with the new implementation
    final linkString = json.encode(link);
    final resourceBytesString = await JsPublicationChannel().getResource(
      linkString,
      asBytes: true,
    );
    final byteList = jsonDecode(resourceBytesString).cast<int>();
    return Uint8List.fromList(byteList);
  }

  @override
  Future<void> goLeft({final bool animated = true}) async {
    JsPublicationChannel.goLeft();
  }

  @override
  Future<void> goRight({final bool animated = true}) async {
    JsPublicationChannel.goRight();
  }

  @override
  Future<void> skipToNext() async {
    R2Log.d('skipToNext is not implemented on web platform');
  }

  @override
  Future<void> skipToPrevious() async {
    R2Log.d('skipToPrevious is not implemented on web platform');
  }

  @override
  Future<void> setEPUBPreferences(EPUBPreferences preferences) async {
    defaultPreferences = preferences;
    JsPublicationChannel().setEPUBPreferences(
      json.encode(preferences.toJson()),
    );
  }

  @override
  Future<void> applyDecorations(
    String id,
    List<ReaderDecoration> decorations,
  ) async {
    R2Log.d('applyDecorations is not implemented on web platform');
  }

  // COMMON PLAYBACK API - BEGIN
  @override
  Future<void> play(Locator? fromLocator) =>
      throw UnimplementedError('play is not implemented on web platform');

  @override
  Future<void> stop() =>
      throw UnimplementedError('stop is not implemented on web platform');

  @override
  Future<void> pause() =>
      throw UnimplementedError('pause is not implemented on web platform');

  @override
  Future<void> resume() =>
      throw UnimplementedError('resume is not implemented on web platform');

  @override
  Future<void> next() =>
      throw UnimplementedError('next is not implemented on web platform');

  @override
  Future<void> previous() =>
      throw UnimplementedError('previous is not implemented on web platform');

  @override
  Future<bool> goToLocator(final Locator locator) async {
    try {
      await JsPublicationChannel.goToLocation(locator.hrefPath);
      return true;
    } on PlatformException catch (e, stackTrace) {
      final pubID = 'unknown';
      throw ReadiumError(
        'Error when navigating to locator: ${e.message}',
        code: e.code,
        data: 'publication id: $pubID. locator: $locator',
        stackTrace: stackTrace,
      );
    }
  }
  // COMMON PLAYBACK API - END

  // TTS API - BEGIN
  @override
  Future<void> ttsEnable(TTSPreferences? preferences) async {
    R2Log.d('ttsEnable is not implemented on web platform');
  }

  @override
  Future<List<ReaderTTSVoice>> ttsGetAvailableVoices() async {
    R2Log.d('ttsGetAvailableVoices is not implemented on web platform');
    return [];
  }

  @override
  Future<void> ttsSetVoice(String voiceIdentifier, String? forLanguage) async {
    R2Log.d('ttsSetVoice is not implemented on web platform');
  }

  @override
  Future<void> setDecorationStyle(
    ReaderDecorationStyle? utteranceDecoration,
    ReaderDecorationStyle? rangeDecoration,
  ) async {
    R2Log.d('setDecorationStyle is not implemented on web platform');
  }

  @override
  Future<void> ttsSetPreferences(TTSPreferences preferences) async {
    R2Log.d('ttsSetPreferences is not implemented on web platform');
  }
  // TTS API - END

  // AUDIOBOOK API - BEGIN
  @override
  Future<void> audioEnable({AudioPreferences? prefs, Locator? fromLocator}) =>
      throw UnimplementedError(
        'audioEnable is not implemented on web platform',
      );

  @override
  Future<void> audioSetPreferences(AudioPreferences prefs) =>
      throw UnimplementedError(
        'audioSetPreferences is not implemented on web platform',
      );
  // AUDIOBOOK API - END

  // @override
  // Stream<ReadiumTimebasedState> get onTimebasedPlayerStateChanged {
  //   // TODO: Implement when karaoke books are supported
  //   // throw UnimplementedError('get onTimebasedPlayerStateChanged is not implemented on web platform');
  //   return const Stream.empty();
  // }

  @override
  Stream<ReadiumError> get onErrorEvent {
    throw UnimplementedError(
      'get onErrorEvent is not implemented on web platform',
    );
  }
}
