## 0.7.1

### Bug Fixes

- **Example app**: Fix `setState() called after dispose()` in `_ReaderPageState` — all async
  methods (`_openEpub`, `_openAudiobook`, `_openWebPub`, `_toggleAudio`, `_nextVoice`) now check
  `mounted` before calling `setState` after an `await`.

### Developer Tools

- Add `scripts/run_integration_tests.sh` — runs integration tests for Android, iOS, and Web
  sequentially from a single command. Scans `flutter devices` once, auto-selects when only one
  device is found per platform, manages ChromeDriver automatically (npx version-matched first,
  system binary fallback), and writes per-platform logs to a gitignored `test_logs/` directory.

### Documentation

- `docs/05-testing/integration-tests.md`: Document the new test runner script; correct CI section
  (CI runs build verification only — integration tests are run locally with the script).
- `docs/platform-specific/web.md`: Mark web publication loading as work in progress with an
  accurate known issues table.

---

## 0.7.0

### New Features

- **Android / Edge tap & swipe navigation**: `setNavigationConfig()` now works on Android, matching iOS behaviour.
  A transparent overlay is placed on top of the Readium navigator (EPUB and PDF) and intercepts touches in
  the configurable left/right edge zones. Center touches always pass through to the reader content.
  - `enableEdgeTapNavigation` — tap the left/right edge to turn pages (default: enabled)
  - `enableSwipeNavigation` — horizontal fling to turn pages (default: enabled)
  - `edgeTapAreaPoints` — edge zone width in dp, clamped to 44–120 (default: 44)
  - In EPUB vertical scroll mode, all overlay gestures are automatically disabled so Readium's
    WebView can handle native scrolling; gestures are re-enabled when scroll mode is turned off.

---

## 0.6.0

### New Features

- **iOS / EPUB scroll mode**: Swipe-back now restores the last scroll position within the previous spine item.
  Previously, swiping back always landed at the start of the item. The position is stored in memory per
  spine item and restored automatically when a backward swipe is detected.
  - Explicit navigation (TOC tap, `skipToPrevious`) is unaffected — it clears the stored position for the
    target item so restoration does not override an intentional jump.
  - History is session-only; it is not persisted across app launches.
  - `onLocatorChanged` fires after restoration, so persistent position saving always reflects the
    final restored position.

---

## 0.5.0

### Breaking Changes

- **EPUBPreferences / PDFPreferences**: Navigation config fields removed. See `flureadium_platform_interface` 0.5.0 changelog for full field list.
  Requires `flureadium_platform_interface` ^0.5.0.

### New Features

- **iOS**: Add `setNavigationConfig` method channel handler in `ReadiumReaderView` and `PdfReaderView`. Navigation UX settings (edge tap, swipe, gesture disabling) are now applied via a dedicated channel call rather than being extracted from the Readium preferences map.
- **iOS**: Remove `developerConfigKeys` filtering workaround from `ReadiumReaderView` and `PdfReaderView`. Readium's `EPUBPreferences.init(fromMap:)` / `PDFPreferences.init(fromMap:)` now receive clean maps with only Readium keys.
- **iOS**: Add `FlutterNavigationConfig` Swift model for deserializing `ReaderNavigationConfig` from the method channel.

## 0.4.0

### Breaking Changes

- **iOS / PDFPreferences**: Rename `disableTextSelectionMenu` to `disableDoubleTapTextSelection`.
  Requires `flureadium_platform_interface` ^0.4.0.

### New Features

- **iOS / PDF**: Fix double-tap word selection in PDF reader. Double-tapping on PDF text no longer
  selects the word or shows the Copy/Look Up/Translate menu. Only the reader overlay controls toggle.
  Long-press text selection with the system menu remains fully functional, matching ePub behavior.
  - Root cause: `UITextNonEditableInteraction.doubleTapInUneditable:` on the lazily-created
    `PDFTextInputView` was intercepting double taps. Previous attempts failed because `PDFTextInputView`
    does not exist at `setupPDFView` time — it is added asynchronously after page rendering.
  - Fix: Deferred traversal (0.1s / 0.5s / 1.0s after `setupPDFView` and each `locationDidChange`)
    finds `PDFTextInputView` and removes `UITextNonEditableInteraction` from it.

## 0.3.4

### Bug Fixes

- **iOS**: Fix `MissingPluginException` on channel `dev.mulev.flureadium/text-locator` (and sibling event channels) when closing a publication.
  - Root cause: `EventStreamHandler.dispose()` was calling `channel.setStreamHandler(nil)` synchronously after sending `FlutterEndOfEventStream`. Flutter's answering "cancel" message arrived after the handler was already gone, producing the exception.
  - Fix: Remove the premature `setStreamHandler(nil)` call. The handler remains registered until the "cancel" round-trip completes; `onCancel` then clears the event sink. The handler is released naturally when the view is deallocated.

## 0.3.3

### New Features

- **iOS**: Add `edgeTapAreaPoints` preference to `EPUBPreferences` and `PDFPreferences` — configures edge tap zone width in absolute points (44–120pt). Replaces the previous percentage-based approach with a fixed-size zone that behaves consistently in split-screen and on all device sizes. Defaults to 44pt (iOS HIG minimum tap target) when null.
  - Requires `flureadium_platform_interface` ^0.3.1.

### Bug Fixes

- **iOS**: Fix spurious `"EPUBPreferences WARN: Cannot map property"` log warnings on every `setPreferences` call and at view init. Developer config keys (`enableEdgeTapNavigation`, `enableSwipeNavigation`, `edgeTapAreaPoints`) are now filtered out before passing the preference map to Readium's `EPUBPreferences.init(fromMap:)` and `PDFPreferences.init(fromMap:)`, which only understand Readium preference keys.
- **iOS**: Fix potential nil crash in `getCurrentLocator` when `currentLocation` returns nil inside the async task.

## 0.3.2

### Bug Fixes

- **iOS**: Fix crash on app close caused by stream handlers sending `FlutterEndOfEventStream` during `deinit`, after the Flutter engine has already torn down its channels.
  - Move all `EventStreamHandler.dispose()` calls from `deinit` to the Dart `"dispose"` method call handler, which runs while the engine is still alive.
  - `deinit` now only nils out references as a safety net without sending any messages.

### Testing

- Add `EventStreamHandlerTests` covering dispose lifecycle, double-dispose safety, send-after-dispose no-op, and listener registration/cancellation.

## 0.3.1

### Bug Fixes

- **Android EPUB**: Fix position restore drift where reopening a book would jump to a different location than the saved position.
  - Root cause: JavaScript `scrollToLocations()` recalculated progression from element bounding rect geometry, overwriting correct StateFlow value.
  - Solution: Skip `scrollToLocations()` during restore when already positioned correctly (within 1% delta), achieving iOS/Android parity.
  - Add grace period validation to suppress late locator emissions after restore settles.
  - Add fragment re-subscription on lifecycle changes to prevent stale listeners.
  - See [Saving Progress Guide](docs/guides/saving-progress.md#testing-restore-behavior) for testing documentation.

### Testing

- Add comprehensive unit tests for Android EPUB restore behavior ([EpubNavigatorRestoreTest.kt](android/src/test/kotlin/dev/mulev/flureadium/navigators/EpubNavigatorRestoreTest.kt)).
- Add manual reopen-loop validation procedure to documentation.
- Improve diagnostic logging for restore flow investigation.

## 0.3.0

- Add `renderFirstPage` API — renders the first page of a PDF as a JPEG image for use as a cover. Uses `PdfRenderer` on Android and `CGPDFDocument` on iOS. No Readium dependency needed.
- Requires `flureadium_platform_interface` ^0.3.0.

## 0.2.0

- Add swipe gesture navigation for EPUB and PDF readers on iOS — swipe left/right to turn pages in edge zones.
- Add `enableEdgeTapNavigation` and `enableSwipeNavigation` preference flags for independently controlling edge tap and swipe page navigation on iOS.
- Requires `flureadium_platform_interface` ^0.2.0.

## 0.1.1

- Fix `.pubignore` excluding `lib/src/web/` which prevented dartdoc generation on pub.dev.

## 0.1.0

- Initial public release of Flureadium.
- Full EPUB 2/3 reading with customizable typography and themes.
- PDF reading support on Android (Pdfium) and iOS (PDFKit).
- Text-to-speech with voice selection, speed, and pitch control.
- Audiobook playback with track navigation and variable speed.
- Media overlay support for synchronized read-along experiences.
- Decoration API for highlights, bookmarks, and annotations.
- ReaderWidget for embedding the reader in Flutter widget trees.
- Position tracking and saving via Locator streams.
- Cross-platform support: Android, iOS, macOS, and Web.
