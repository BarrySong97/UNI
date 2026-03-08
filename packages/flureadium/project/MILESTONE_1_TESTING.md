# Milestone 1: Testing Infrastructure & Coverage

**Priority**: Critical
**Prerequisite for**: All other milestones

---

## Objective

Establish comprehensive test coverage to enable safe refactoring and ensure reliability before pub.dev publication.

---

## Current State

| Metric | Value |
|--------|-------|
| Test files | 5 |
| Estimated coverage | ~10% |
| Mock completeness | 23 unimplemented methods |
| Widget tests | 0 |
| Integration tests | 0 |

---

## Tasks

### 1.1 Complete Mock Platform Implementation

**File**: `flureadium/test/flureadium_test.dart`

Replace all `throw UnimplementedError()` methods with proper mock implementations:

```dart
class MockFlureadiumPlatform extends FlureadiumPlatform {
  Publication? _mockPublication;
  Locator? _mockLocator;

  @override
  Future<Publication?> loadPublication(String pubUrl) async {
    return _mockPublication;
  }

  void setMockPublication(Publication pub) {
    _mockPublication = pub;
  }

  // ... implement all 23 methods
}
```

**Methods to implement**:
- `loadPublication`, `openPublication`, `closePublication`
- `goLeft`, `goRight`, `goToLocator`, `goByLink`
- `ttsEnable`, `ttsGetAvailableVoices`, `ttsSetVoice`, `ttsSetPreferences`
- `audioEnable`, `audioSeekBy`, `audioSetPreferences`
- `play`, `pause`, `resume`, `stop`, `next`, `previous`
- `setEPUBPreferences`, `setDefaultPreferences`
- `applyDecorations`, `setDecorationStyle`, `setCustomHeaders`

### 1.2 Unit Tests for Core Models

**Location**: `flureadium_platform_interface/test/`

#### Publication Model Tests
```
test/models/publication_test.dart
├── fromJson() parsing
├── toJson() serialization
├── linkWithHref() lookup
├── linkWithRel() lookup
├── locatorFromLink() conversion
├── coverLink extraction
└── Edge cases (empty collections, null values)
```

#### Locator Model Tests
```
test/models/locator_test.dart
├── fromJson() with all location types
├── toJson() roundtrip
├── Equality comparison
├── copyWith() modifications
├── Fragment parsing (#t=123.45, CSS selectors)
└── Text context handling
```

#### Preferences Tests
```
test/models/preferences_test.dart
├── EPUBPreferences serialization
├── TTSPreferences serialization
├── AudioPreferences serialization
├── Default values
└── Merge behavior
```

### 1.3 Method Channel Integration Tests

**Location**: `flureadium/test/integration/`

Test the Dart-to-native communication layer:

```dart
// test/integration/method_channel_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelFlureadium platform;
  late List<MethodCall> calls;

  setUp(() {
    platform = MethodChannelFlureadium();
    calls = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.mulev.flureadium/main'),
      (call) async {
        calls.add(call);
        return _mockResponse(call);
      },
    );
  });

  test('openPublication sends correct arguments', () async {
    await platform.openPublication('file:///test.epub');

    expect(calls.last.method, 'openPublication');
    expect(calls.last.arguments['pubUrl'], 'file:///test.epub');
  });

  // Test all method channel calls
}
```

### 1.4 Widget Tests for ReaderWidget

**Location**: `flureadium/test/widget/`

```dart
// test/widget/reader_widget_test.dart
void main() {
  testWidgets('ReaderWidget shows loading state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderWidget(
          onReaderCreated: (_) {},
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ReaderWidget handles error state', (tester) async {
    // Test error display
  });

  testWidgets('ReaderWidget responds to orientation changes', (tester) async {
    // Test orientation handling
  });
}
```

### 1.5 Stream/Event Tests

Test the event stream behavior:

```dart
// test/streams/event_streams_test.dart
void main() {
  test('onTextLocatorChanged emits distinct values', () async {
    final flureadium = Flureadium();
    final locators = <Locator?>[];

    flureadium.onTextLocatorChanged.listen(locators.add);

    // Simulate duplicate locator emissions
    // Verify only distinct values are emitted
  });

  test('onTimebasedPlayerStateChanged debounces rapid updates', () async {
    // Test debouncing behavior
  });
}
```

### 1.6 Exception Handling Tests

```dart
// test/exceptions/exception_test.dart
void main() {
  group('OpeningReadiumException', () {
    test('fromHttpStatus maps 404 to notFound', () {
      final exception = OpeningReadiumException.fromHttpStatus(404, 'Not found');
      expect(exception.type, OpeningExceptionType.notFound);
    });

    test('fromHttpStatus maps 403 to forbidden', () {
      final exception = OpeningReadiumException.fromHttpStatus(403, 'Forbidden');
      expect(exception.type, OpeningExceptionType.forbidden);
    });

    // Test all HTTP status mappings
  });
}
```

---

## Test Structure

```
flureadium/
├── test/
│   ├── flureadium_test.dart           # Main plugin tests
│   ├── mocks/
│   │   └── mock_platform.dart         # Complete mock implementation
│   ├── integration/
│   │   └── method_channel_test.dart   # Channel communication tests
│   ├── widget/
│   │   └── reader_widget_test.dart    # Widget tests
│   └── streams/
│       └── event_streams_test.dart    # Stream behavior tests

flureadium_platform_interface/
├── test/
│   ├── models/
│   │   ├── publication_test.dart
│   │   ├── locator_test.dart
│   │   ├── metadata_test.dart
│   │   └── preferences_test.dart
│   ├── exceptions/
│   │   └── exception_test.dart
│   └── utils/
│       ├── href_test.dart             # (exists)
│       ├── uri_template_test.dart     # (exists)
│       └── json_test.dart             # (exists)
```

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Line coverage | >70% |
| Branch coverage | >60% |
| All mocks implemented | 100% |
| Widget tests | >5 tests |
| Integration tests | >10 tests |
| All tests passing | 100% |

---

## Commands

```bash
# Run all tests
flutter test > /dev/null 2>&1 && echo "TESTS PASSED" || echo "TESTS FAILED"

# Run with coverage
flutter test --coverage

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## Dependencies

Add to `pubspec.yaml` (dev_dependencies):

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0          # Modern mocking
  fake_async: ^1.3.0        # Time-based testing
  stream_channel: ^2.1.0    # Stream testing utilities
```

---

## Estimated Effort

| Task | Complexity | Notes |
|------|------------|-------|
| 1.1 Mock implementation | Medium | ~2-3 hours |
| 1.2 Model unit tests | Medium | ~4-5 hours |
| 1.3 Integration tests | High | ~3-4 hours |
| 1.4 Widget tests | Medium | ~2-3 hours |
| 1.5 Stream tests | Low | ~1-2 hours |
| 1.6 Exception tests | Low | ~1 hour |

---

*Part of [Flureadium Analysis](ANALYSIS.md)*
