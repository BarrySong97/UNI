import Flutter
import Combine
import UIKit
import WebKit
import MediaPlayer
import ReadiumNavigator
import ReadiumShared

private let TAG = "ReadiumReaderPlugin"

internal var currentPublicationUrlStr: String?
internal var currentPublication: Publication?
// iOS 多实例核心：按 sessionId 保存 publication，避免只有一个 currentPublication。
internal var publicationBySession: [String: Publication] = [:]
internal var publicationUrlBySession: [String: String] = [:]
internal var currentReaderView: ReadiumReaderView?
// 记录 sessionId -> readerView，用于 session 定向 goToLocator。
internal var readerViewBySession: [String: ReadiumReaderView] = [:]
internal var currentPdfReaderView: PdfReaderView?

func getCurrentPublication(sessionId: String? = nil) -> Publication? {
  // 兼容旧逻辑：未传 sessionId 时仍走 legacy currentPublication。
  if let sessionId {
    return publicationBySession[sessionId]
  }
  return currentPublication
}

func setCurrentReadiumReaderView(_ readerView: ReadiumReaderView?, sessionId: String?) {
  if let sessionId {
    if let readerView {
      readerViewBySession[sessionId] = readerView
    } else {
      readerViewBySession.removeValue(forKey: sessionId)
    }
  }
  currentReaderView = readerView
}

func setCurrentPdfReaderView(_ readerView: PdfReaderView?) {
  currentPdfReaderView = readerView
}

public class FlureadiumPlugin: NSObject, FlutterPlugin, ReadiumShared.WarningLogger, TimebasedListener {

  static var registrar: FlutterPluginRegistrar? = nil

  /// TTS Decoration style
  internal var ttsUtteranceDecorationStyle: Decoration.Style? = .highlight(tint: .yellow)
  internal var ttsRangeDecorationStyle: Decoration.Style? = .underline(tint: .black)

  /// Timebased player events & state
  internal var timebasedPlayerStateStreamHandler: EventStreamHandler?
  internal var lastTimebasedPlayerState: ReadiumTimebasedState? = nil

  /// Timebased Navigator. Can be TTS, Audio or MediaOverlay implementations.
  internal var timebasedNavigator: FlutterTimebasedNavigator? = nil

  lazy var fallbackChapterTitle: LocalizedString = LocalizedString.localized([
    "en": "Chapter",
    "da": "Kapitel",
    "sv": "Kapitel",
    "no": "Kapittel",
    "is": "Kafli",
  ])

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "dev.mulev.flureadium/main", binaryMessenger: registrar.messenger())
    let instance = FlureadiumPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.timebasedPlayerStateStreamHandler = EventStreamHandler(withName: "timebased-state", messenger: registrar.messenger())

    // Register reader view factory
    let factory = ReadiumReaderViewFactory(registrar: registrar)
    registrar.register(factory, withId: readiumReaderViewType)

    self.registrar = registrar

    // Pre-warm WKWebView process pool so the first real WKWebView creation is faster.
    Self.prewarmWebView()
  }

  private func logPerf(_ stage: String, elapsedMs: Int? = nil, extras: [String: Any?] = [:]) {
    var parts: [String] = ["[PERF][Reader][iOS]", stage]
    if let elapsedMs {
      parts.append("elapsed=\(elapsedMs)ms")
    }
    for (key, value) in extras {
      guard let value else { continue }
      parts.append("\(key)=\(value)")
    }
    print(parts.joined(separator: " "))
  }

  private static var _warmupView: WKWebView?

  private static func prewarmWebView() {
    let warmup = WKWebView(frame: .zero)
    warmup.loadHTMLString("<html></html>", baseURL: nil)
    _warmupView = warmup
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      _warmupView = nil
    }
  }

  public func log(_ warning: Warning) {
    print(TAG, "Error in Readium: \(warning)")
  }

  private func resolvePublicationFromSession(_ sessionId: String?) -> Publication? {
    guard let sessionId else {
      return currentPublication
    }
    return publicationBySession[sessionId]
  }

  private func resolveReaderViewFromSession(_ sessionId: String?) -> ReadiumReaderView? {
    guard let sessionId else {
      return currentReaderView
    }
    return readerViewBySession[sessionId]
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setCustomHeaders":
      guard let args = call.arguments as? [String: Any],
            let httpHeaders = args["httpHeaders"] as? [String: String] else {
        return result(FlutterError.init(
          code: "InvalidArgument",
          message: "Invalid custom headers map",
          details: nil))
      }
      sharedReadium.setAdditionalHeaders(httpHeaders)
      result(nil)
    case "dispose":
      closePublication()
      self.timebasedPlayerStateStreamHandler?.dispose()
      self.timebasedPlayerStateStreamHandler = nil
      result(nil)
    case "closePublication":
      self.closePublication()
      result(nil)
    case "closePublicationForSession":
      guard let args = call.arguments as? [String: Any],
            let sessionId = args["sessionId"] as? String else {
        result(nil)
        return
      }
      self.closePublication(sessionId: sessionId)
      result(nil)
    case "openPublication":
      let args = call.arguments as! [Any?]
      let pubUrlStr = args[0] as! String
      self.openPublication(pubUrlStr: pubUrlStr, sessionId: nil, result: result)
    case "openPublicationWithSession":
      guard let args = call.arguments as? [String: Any],
            let pubUrlStr = args["pubUrl"] as? String,
            let sessionId = args["sessionId"] as? String else {
        result(FlutterError.init(
          code: "InvalidArgument",
          message: "Invalid arguments for openPublicationWithSession",
          details: nil))
        return
      }
      self.openPublication(pubUrlStr: pubUrlStr, sessionId: sessionId, result: result)
    case "loadPublication":
      let args = call.arguments as! [Any?]
      let pubUrlStr = args[0] as! String

      Task.detached(priority: .high) {
        do {
          let pub: Publication = try await self.loadPublication(fromUrlStr: pubUrlStr).get()

          let jsonManifest = pub.jsonManifest
          pub.close()

          await MainActor.run {
            result(jsonManifest)
          }
        } catch let err as ReadiumError {
          await MainActor.run {
            result(err.toFlutterError())
          }
        }
      }
    case "getLinkContent":
      let args = call.arguments as! [Any?]
      // TODO: Do we need asString?
      //let asString = args[1] as? Bool ?? true
      let asString = true
      guard let linkStr = args[0] as? String,
            let publication = currentPublication,
            let link = try? Link(fromJsonString: linkStr) else {
        return result(FlutterError.init(
          code: "InvalidArgument",
          message: "Failed to get link content",
          details: nil))
      }
      Task.detached(priority: .high) {
        let resource = publication.get(link)
        do {
          if (asString) {
            let linkContent = try await resource?.readAsString(encoding: .utf8).get()
            await MainActor.run {
              result(linkContent)
            }
          } else {
            let data = try await resource!.read().get()
            await MainActor.run {
              result(FlutterStandardTypedData(bytes: data))
            }
          }
        } catch let err {
          await MainActor.run {
            print("\(TAG).getLinkContent exception: \(err)")
            result(
              FlutterError.init(
                code: "InternalError",
                message: err.localizedDescription,
                details: "Something went wrong fetching link content."))
          }
        }
      }

    case "ttsEnable":
      Task.detached(priority: .high) {
        do {
          let args = call.arguments as? Dictionary<String, Any>,
              ttsPrefs = (try? TTSPreferences(fromMap: args ?? [:])) ?? TTSPreferences()
          //try await self.ttsEnable(withPreferences: ttsPrefs)

          guard let publication = getCurrentPublication() else {
            throw ReadiumError.notFound("No publication opened")
          }

          Task { @MainActor in
            // Start TTS from the reader's current location
            let currentLocation = currentReaderView?.getCurrentLocation()
            self.timebasedNavigator = FlutterTTSNavigator(publication: publication, preferences: ttsPrefs, initialLocator: currentLocation)
            self.timebasedNavigator?.listener = self
            Task {
              await self.timebasedNavigator?.initNavigator()
            }
            result(nil)
          }
        } catch {
          Task { @MainActor in
            result(FlutterError.init(
              code: "TTSError",
              message: "Failed to enable TTS: \(error.localizedDescription)",
              details: nil))
          }
        }
      }
    case "ttsGetAvailableVoices":
      guard let ttsNavigator = self.timebasedNavigator as? FlutterTTSNavigator else {
        return result(FlutterError.init(
          code: "TTSError",
          message: "TTS Navigator not initialized",
          details: nil))
      }
      let availableVoices = ttsNavigator.ttsGetAvailableVoices()
      result(availableVoices.compactMap { $0.jsonString })
    case "ttsSetVoice":
      let args = call.arguments as! [Any?]
      let voiceIdentifier = args[0] as! String
      // TODO: language might be supplied as args[1], ignored on iOS for now.

      guard let ttsNavigator = self.timebasedNavigator as? FlutterTTSNavigator else {
        return result(FlutterError.init(
          code: "TTSError",
          message: "TTS Navigator not initialized",
          details: nil))
      }

      do {
        try ttsNavigator.ttsSetVoice(voiceIdentifier: voiceIdentifier)
        result(nil)
      } catch {
        result(FlutterError.init(
          code: "TTSError",
          message: "Invalid voice identifier: \(error.localizedDescription)",
          details: nil))
      }
    case "setDecorationStyle":
      let args = call.arguments as! [Any?]

      if let uttDecorationMap = args[0] as? Dictionary<String, String> {
        ttsUtteranceDecorationStyle = try! Decoration.Style(fromMap: uttDecorationMap)
      }

      if let rangeDecorationMap = args[1] as? Dictionary<String, String> {
        ttsRangeDecorationStyle = try! Decoration.Style(fromMap: rangeDecorationMap)
      }
      result(nil)
    case "ttsSetPreferences":
      let args = call.arguments as! Dictionary<String, String>
      guard let ttsNavigator = self.timebasedNavigator as? FlutterTTSNavigator else {
        return result(FlutterError.init(
          code: "TTSError",
          message: "TTS Navigator not initialized",
          details: nil))
      }
      do {
        let ttsPrefs = try TTSPreferences(fromMap: args)
        ttsNavigator.ttsSetPreferences(prefs: ttsPrefs)
        result(nil)
      } catch {
        result(FlutterError.init(
          code: "TTSError",
          message: "Failed to deserialize TTSPreferences: \(error.localizedDescription)",
          details: nil))
      }
    case "play":
      let args = call.arguments as! [Any?]
      var locator: Locator? = nil
      if let locatorJson = args.first as? Dictionary<String, Any> {
        locator = try? Locator(json: locatorJson, warnings: self)
      }

      Task.detached(priority: .high) {
        // If no locator provided, try to start from current ReaderView position.
        if (locator == nil) {
          locator = await currentReaderView?.getFirstVisibleLocator()
        }
        await self.timebasedNavigator?.play(fromLocator: locator)

        await MainActor.run {
          result(nil)
        }
      }
    case "stop":
      Task { @MainActor in
        self.timebasedNavigator?.dispose()
        self.timebasedNavigator = nil
        self.updateReaderViewTimebasedDecorations([])
      }
      result(nil)
    case "pause":
      Task { @MainActor in
        await self.timebasedNavigator?.pause()
      }
      result(nil)
    case "resume":
      Task { @MainActor in
        await self.timebasedNavigator?.resume()
      }
      result(nil)
    case "togglePlayback":
      Task { @MainActor in
        await self.timebasedNavigator?.togglePlayPause()
      }
      result(nil)
    case "next":
      Task { @MainActor in
        await self.timebasedNavigator?.seekForward()
      }
      result(nil)
    case "previous":
      Task { @MainActor in
        await self.timebasedNavigator?.seekBackward()
      }
      result(nil)
    case "goToLocator":
      Task.detached(priority: .high) {
        guard let args = call.arguments as? [Any?],
              let locatorJson = args.first as? Dictionary<String, Any>,
              let locator = try? Locator(json: locatorJson, warnings: self)
        else {
          await MainActor.run {
            result(FlutterError.init(
              code: "InvalidArgument",
              message: "Failed to parse locator",
              details: nil))
          }
          return
        }
        var navigated = false

        // Timebased Naviagor seek
        if (self.timebasedNavigator != nil) {
          navigated = await self.timebasedNavigator?.seek(toLocator: locator) ?? false
        }
        // ReaderView goTo
        else if (currentReaderView != nil) {
          await currentReaderView?.goToLocator(locator: locator, animated: false)
          navigated = true
        }
        await MainActor.run { [navigated] in
          result(navigated)
        }
      }
    case "goToLocatorWithSession":
      Task.detached(priority: .high) {
        guard let args = call.arguments as? [Any?],
              let locatorJson = args.first as? Dictionary<String, Any>,
              let sessionId = args.count > 1 ? args[1] as? String : nil,
              let locator = try? Locator(json: locatorJson, warnings: self)
        else {
          await MainActor.run {
            result(FlutterError.init(
              code: "InvalidArgument",
              message: "Failed to parse locator/sessionId",
              details: nil))
          }
          return
        }
        var navigated = false
        if let readerView = self.resolveReaderViewFromSession(sessionId) {
          await readerView.goToLocator(locator: locator, animated: false)
          navigated = true
        }
        await MainActor.run { [navigated] in
          result(navigated)
        }
      }
    case "audioEnable":
      guard let args = call.arguments as? [Any?],
            let publication = currentPublication,
            let pubUrlStr = currentPublicationUrlStr else {
        return result(FlutterError.init(
          code: "InvalidArgument",
          message: "No publication open or Invalid parameters to audioEnable: \(call.arguments.debugDescription)",
          details: nil))
      }
      Task.detached(priority: .high) {
        // Get preferences via arg, or use defaults (empty map).
        let prefsMap = args[0] as? Dictionary<String, Any>,
            prefs = try FlutterAudioPreferences.init(fromMap: prefsMap ?? [:])
        var locator: Locator? = nil
        if let locatorJson = args[1] as? Dictionary<String, Any> {
          locator = try? Locator(json: locatorJson, warnings: self)
        }

        if (publication.containsMediaOverlays) {
          do {
            // MediaOverlayNavigator will modify the Publication readingOrder, so we first load a modifiable copy.
            let modifiablePublicationCopy = try await self.loadPublication(fromUrlStr: pubUrlStr).get()
            await MainActor.run { [locator] in
              self.timebasedNavigator = FlutterMediaOverlayNavigator(publication: modifiablePublicationCopy, preferences: prefs, initialLocator: locator)
            }
          } catch (let err) {
            return result(FlutterError.init(
              code: "Error",
              message: "Failed to reload a modifiable publication copy from: \(pubUrlStr)",
              details: err))
          }
        } else {
          if (!publication.conforms(to: Publication.Profile.audiobook)) {
            return result(FlutterError.init(
              code: "InvalidArgument",
              message: "Publication does not contain MediaOverlays or conforms to AudioBook profile. Args: \(call.arguments.debugDescription)",
              details: nil))
          }
          self.timebasedNavigator = await FlutterAudioNavigator(publication: publication, preferences: prefs, initialLocator: locator)
        }

        self.timebasedNavigator?.listener = self
        await self.timebasedNavigator?.initNavigator()

        await MainActor.run {
          result(nil)
        }
      }
    case "audioSetPreferences":
      Task.detached(priority: .high) {
        guard let audioNavigator = self.timebasedNavigator as? FlutterAudioNavigator,
              let prefsMap = call.arguments as? Dictionary<String, Any>,
              let prefs = try? FlutterAudioPreferences.init(fromMap: prefsMap) else {
          return result(FlutterError.init(
            code: "InvalidArgument",
            message: "AudioNavigator not initialized or Invalid parameters to audioSetPreferences: \(call.arguments.debugDescription)",
            details: nil))
        }
        Task { @MainActor in
          audioNavigator.setAudioPreferences(prefs)
          result(nil)
        }
      }
    case "audioSeekBy":
      Task { @MainActor in
        guard let seekOffset = call.arguments as? Double else {
          return result(FlutterError.init(
            code: "InvalidArgument",
            message: "Invalid parameters to audioSeek: \(call.arguments.debugDescription)",
            details: nil))
        }
        let _ = await self.timebasedNavigator?.seekRelative(byOffsetSeconds: seekOffset)
        result(nil)
      }

    case "renderFirstPage":
      let args = call.arguments as! [Any?]
      let pubUrlStr = args[0] as! String
      let maxWidth = args[1] as! Int
      let maxHeight = args[2] as! Int

      Task.detached(priority: .background) {
        let imageData = Self.renderFirstPage(
          pubUrlStr: pubUrlStr,
          maxWidth: maxWidth,
          maxHeight: maxHeight
        )
        await MainActor.run {
          if let data = imageData {
            result(FlutterStandardTypedData(bytes: data))
          } else {
            result(nil)
          }
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func timebasedNavigator(_: any FlutterTimebasedNavigator, didChangeState state: ReadiumTimebasedState) {
    print(TAG, "TimebasedNavigator state: \(state)")
    timebasedPlayerStateStreamHandler?.sendEvent(state.toJsonString())
  }

  public func timebasedNavigator(_: any FlutterTimebasedNavigator, encounteredError error: any Error, withDescription description: String?) {
    print(TAG, "TimebasedNavigator error: \(error), description: \(String(describing: description))")
    // TODO: submit on error stream
  }

  public func timebasedNavigator(_: any FlutterTimebasedNavigator, reachedLocator locator: ReadiumShared.Locator, readingOrderLink: ReadiumShared.Link?) {
    print(TAG, "TimebasedNavigator reachedLocator: \(locator), readingOrderLink: \(String(describing: readingOrderLink))")

    Task { @MainActor [locator] in
      await currentReaderView?.goToLocator(locator: locator, animated: false)
    }
  }

  public func timebasedNavigator(_: any FlutterTimebasedNavigator, requestsHighlightAt locator: ReadiumShared.Locator?, withWordLocator wordLocator: ReadiumShared.Locator?) {
    print(TAG, "TimebasedNavigator requestsHighlightAt: \(String(describing: locator)), withWordLocator: \(String(describing: wordLocator))")

    // Update Reader text decorations
    var decorations: [Decoration] = []
    if let uttLocator = locator,
       let uttDecorationStyle = ttsUtteranceDecorationStyle {
      decorations.append(Decoration(
        id: "tts-utt", locator: uttLocator, style: uttDecorationStyle
      ))
    }
    if let rangeLocator = wordLocator,
       let rangeDecorationStyle = ttsRangeDecorationStyle {
      decorations.append(Decoration(
        id: "tts-range", locator: rangeLocator, style: rangeDecorationStyle
      ))
    }
    Task { @MainActor [decorations] in
      updateReaderViewTimebasedDecorations(decorations)
    }
  }
}

/// Extension for handling publication interactions
extension FlureadiumPlugin {

  @MainActor
  func updateReaderViewTimebasedDecorations(_ decorations: [Decoration]) {
    currentReaderView?.applyDecorations(decorations, forGroup: "timebased-highlight")
  }

  func clearNowPlaying() {
    NowPlayingInfo.shared.clear()
  }

  private func loadPublication (
    fromUrlStr: String
  ) async -> Result<Publication, ReadiumError> {
    var pubUrlStr = fromUrlStr

    // Handle local file paths properly
    let url: URL
    if pubUrlStr.hasPrefix("http://") || pubUrlStr.hasPrefix("https://") {
      // Remote URL
      let encodedUrlStr = pubUrlStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
      guard let remoteUrl = URL(string: encodedUrlStr!) else {
        return .failure(ReadiumError.notFound("Invalid pub URL: \(pubUrlStr)"))
      }
      url = remoteUrl
    } else {
      // Local file path - remove file:// prefix if present
      if pubUrlStr.hasPrefix("file://") {
        pubUrlStr = String(pubUrlStr.dropFirst(7))
      }
      url = URL(fileURLWithPath: pubUrlStr)
    }

    guard let absUrl = url.anyURL.absoluteURL else {
      return .failure(ReadiumError.notFound("Failed to get AbsoluteUrl: \(pubUrlStr)"))
    }

    print("Attempting to open publication at: \(absUrl)")
    do {
      let pub: (Publication, Format) = try await self.openPublication(at: absUrl, allowUserInteraction: true, sender: nil)
      let mediaType: String = pub.1.mediaType?.string ?? "unknown"
      print("Opened publication: identifier: \(pub.0.metadata.identifier ?? "[no-ident]") format: \(mediaType)")
      return .success(pub.0)
    } catch let error {
      print("Failed to open publication: \(error)")
      return .failure(error)
    }
  }

  private func openPublication(
    at url: AbsoluteURL,
    allowUserInteraction: Bool,
    sender: UIViewController?
  ) async throws(ReadiumError) -> (Publication, Format) {
    do {
      let asset = try await sharedReadium.assetRetriever!.retrieve(url: url).get()

      let publication = try await sharedReadium.publicationOpener!.open(
        asset: asset,
        allowUserInteraction: allowUserInteraction,
        sender: sender
      ).get()

      return (publication, asset.format)
    } catch let err {
      throw err.toReadiumError()
    }
  }

  /// Tries to open a publication using a cached manifest JSON file,
  /// bypassing the expensive OPF parsing step.
  /// Prefers a pre-extracted directory (fastest) over opening the ZIP.
  private func openPublicationFromCache(urlStr: String) async -> Publication? {
    let filePath = Self.resolveLocalFilePath(urlStr)
    guard let filePath = filePath else { return nil }

    let cachePath = filePath + ".manifest.json"
    let cacheURL = URL(fileURLWithPath: cachePath)

    guard FileManager.default.fileExists(atPath: cachePath),
          let jsonData = try? Data(contentsOf: cacheURL),
          let jsonObj = try? JSONSerialization.jsonObject(with: jsonData),
          let manifest = try? Manifest(json: jsonObj) else {
      return nil
    }

    // Fast path: use pre-extracted directory.
    let extractedDir = filePath.replacingOccurrences(of: ".epub", with: "")
    var isDir: ObjCBool = false
    if FileManager.default.fileExists(atPath: extractedDir, isDirectory: &isDir),
       isDir.boolValue {
      let dirURL = URL(fileURLWithPath: extractedDir)
      if let fileURL = dirURL.anyURL.absoluteURL?.fileURL,
         let container = try? await DirectoryContainer(directory: fileURL) {
        print("[PERF] Using DirectoryContainer: \(extractedDir)")
        return Publication(manifest: manifest, container: container)
      } else {
        print("[PERF] DirectoryContainer failed for: \(extractedDir)")
      }
    } else {
      print("[PERF] Extracted directory not found: \(extractedDir)")
    }

    // Fallback: open ZIP with known format.
    let fileURL = URL(fileURLWithPath: filePath)
    guard let absUrl = fileURL.anyURL.absoluteURL else { return nil }

    let epubFormat = Format(
      specifications: .zip, .epub,
      mediaType: .epub,
      fileExtension: .epub
    )
    guard let asset = try? await sharedReadium.assetRetriever!.retrieve(url: absUrl, format: epubFormat).get(),
          case let .container(containerAsset) = asset else {
      return nil
    }

    return Publication(manifest: manifest, container: containerAsset.container)
  }

  /// Saves manifest JSON to a cache file next to the EPUB.
  private func cacheManifest(urlStr: String, publication: Publication) {
    guard let filePath = Self.resolveLocalFilePath(urlStr),
          let jsonManifest = publication.jsonManifest,
          let data = jsonManifest.data(using: .utf8) else { return }
    let cachePath = filePath + ".manifest.json"
    try? data.write(to: URL(fileURLWithPath: cachePath))
  }

  /// Strips file:// prefix from a URL string to get a local file path.
  /// Returns nil for remote URLs.
  private static func resolveLocalFilePath(_ urlStr: String) -> String? {
    if urlStr.hasPrefix("http://") || urlStr.hasPrefix("https://") {
      return nil
    }
    var path = urlStr
    if path.hasPrefix("file://") {
      path = String(path.dropFirst(7))
    }
    return path
  }

  private func openPublication(
    pubUrlStr: String,
    sessionId: String?,
    result: @escaping FlutterResult
  ) {
    Task.detached(priority: .high) {
      await MainActor.run {
        self.logPerf(
          "native.open_publication.start",
          extras: ["path": pubUrlStr, "sessionId": sessionId ?? "legacy"]
        )
      }
      let startTime = CFAbsoluteTimeGetCurrent()

      if let cachedPub = await self.openPublicationFromCache(urlStr: pubUrlStr) {
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        await MainActor.run {
          self.logPerf(
            "native.open_publication.cache_hit",
            elapsedMs: Int(elapsed),
            extras: ["path": pubUrlStr, "sessionId": sessionId ?? "legacy"]
          )
        }
        if let sessionId {
          publicationBySession[sessionId]?.close()
          publicationBySession[sessionId] = cachedPub
          publicationUrlBySession[sessionId] = pubUrlStr
        } else {
          currentPublication?.close()
          currentPublication = cachedPub
          currentPublicationUrlStr = pubUrlStr
        }
        await MainActor.run { result(cachedPub.jsonManifest) }
        return
      }

      let cacheMissTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
      await MainActor.run {
        self.logPerf(
          "native.open_publication.cache_miss",
          elapsedMs: Int(cacheMissTime),
          extras: ["path": pubUrlStr, "sessionId": sessionId ?? "legacy"]
        )
      }

      do {
        let pub: Publication = try await self.loadPublication(fromUrlStr: pubUrlStr).get()
        let parseElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        await MainActor.run {
          self.logPerf(
            "native.open_publication.full_parse",
            elapsedMs: Int(parseElapsed),
            extras: ["path": pubUrlStr, "sessionId": sessionId ?? "legacy"]
          )
        }

        if let sessionId {
          publicationBySession[sessionId]?.close()
          publicationBySession[sessionId] = pub
          publicationUrlBySession[sessionId] = pubUrlStr
        } else {
          currentPublication = pub
          currentPublicationUrlStr = pubUrlStr
        }
        self.cacheManifest(urlStr: pubUrlStr, publication: pub)
        await MainActor.run {
          result(pub.jsonManifest)
        }
      } catch let err as ReadiumError {
        await MainActor.run {
          self.logPerf(
            "native.open_publication.error",
            extras: ["path": pubUrlStr, "error": err.localizedDescription]
          )
        }
        await MainActor.run {
          result(err.toFlutterError())
        }
      }
    }
  }

  private func closePublication(sessionId: String? = nil) {
    // Clean-up any resources associated with the publication.
    Task { @MainActor in
      self.timebasedNavigator?.dispose()
      self.timebasedNavigator = nil
      if let sessionId {
        publicationBySession[sessionId]?.close()
        publicationBySession.removeValue(forKey: sessionId)
        publicationUrlBySession.removeValue(forKey: sessionId)
        readerViewBySession.removeValue(forKey: sessionId)
        if currentReaderView?.sessionId == sessionId {
          currentReaderView = nil
        }
      } else {
        currentPublication?.close()
        currentPublication = nil
        currentPublicationUrlStr = nil
        for (_, publication) in publicationBySession {
          publication.close()
        }
        publicationBySession.removeAll()
        publicationUrlBySession.removeAll()
        readerViewBySession.removeAll()
      }
    }
  }

  /// Renders the first page of a PDF file as a JPEG image using Core Graphics.
  static func renderFirstPage(pubUrlStr: String, maxWidth: Int, maxHeight: Int) -> Data? {
    var urlStr = pubUrlStr
    if !urlStr.hasPrefix("file://") && !urlStr.hasPrefix("http") {
      urlStr = "file://\(urlStr)"
    }

    guard let url = URL(string: urlStr),
          let document = CGPDFDocument(url as CFURL),
          let page = document.page(at: 1) else {
      return nil
    }

    let pageRect = page.getBoxRect(.mediaBox)
    let scale = min(
      CGFloat(maxWidth) / pageRect.width,
      CGFloat(maxHeight) / pageRect.height,
      1.0
    )
    let width = Int(pageRect.width * scale)
    let height = Int(pageRect.height * scale)

    UIGraphicsBeginImageContextWithOptions(
      CGSize(width: width, height: height),
      true,
      1.0
    )
    guard let context = UIGraphicsGetCurrentContext() else {
      UIGraphicsEndImageContext()
      return nil
    }

    context.setFillColor(UIColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: scale, y: -scale)
    context.drawPDFPage(page)

    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return image?.jpegData(compressionQuality: 0.85)
  }
}
