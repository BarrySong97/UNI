# Milestone 4: Code Quality Refactoring

**Priority**: Medium
**Depends on**: Milestone 1 (Testing) - tests enable safe refactoring

---

## Objective

Improve code maintainability by refactoring large classes, resolving technical debt, and adopting modern Dart patterns.

---

## Current State

| Issue | Count |
|-------|-------|
| Files >300 lines | 6 |
| TODO comments | 17 files |
| Unimplemented errors | 23+ methods |
| Manual JSON parsing | Extensive |

---

## Tasks

### 4.1 Refactor Large Classes

#### 4.1.1 mediatype.dart (488 lines)

**Current structure**: Single file with MediaType class and extensive MIME type constants.

**Refactoring plan**:
```
flureadium_platform_interface/lib/src/shared/mediatype/
├── mediatype.dart           # Core MediaType class (~100 lines)
├── mediatype_constants.dart # MIME type constants (~200 lines)
├── mediatype_extensions.dart # Extension methods (~50 lines)
└── mediatype.g.dart         # Generated JSON serialization
```

**Changes**:
```dart
// mediatype.dart - keep only the class definition
class MediaType {
  final String type;
  final String subtype;
  final Map<String, String> parameters;

  // Core methods only
}

// mediatype_constants.dart - extract constants
abstract class MediaTypes {
  static const epub = MediaType.parse('application/epub+zip');
  static const pdf = MediaType.parse('application/pdf');
  static const html = MediaType.parse('text/html');
  // ... all other constants
}
```

#### 4.1.2 metadata.dart (393 lines)

**Refactoring plan**:
```
flureadium_platform_interface/lib/src/shared/publication/
├── metadata.dart            # Core Metadata class (~150 lines)
├── contributor.dart         # Contributor model (~80 lines)
├── subject.dart             # Subject model (~50 lines)
├── reading_progression.dart # ReadingProgression enum (~30 lines)
└── metadata.g.dart          # Generated serialization
```

#### 4.1.3 locator.dart (386 lines)

**Refactoring plan**:
```
flureadium_platform_interface/lib/src/shared/publication/
├── locator.dart             # Locator class (~120 lines)
├── locations.dart           # Locations class (~100 lines)
├── locator_text.dart        # LocatorText class (~50 lines)
├── dom_range.dart           # DomRange class (~50 lines)
└── locator.g.dart           # Generated serialization
```

#### 4.1.4 flureadium_web.dart (349 lines)

**Refactoring plan**:
```
flureadium/lib/src/web/
├── flureadium_web.dart      # Main plugin class (~150 lines)
├── js_interop.dart          # JavaScript interop helpers (~80 lines)
├── json_transformer.dart    # Publication JSON transformation (~100 lines)
└── web_stream_handlers.dart # Stream handling (~50 lines)
```

**Extract the JSON transformation**:
```dart
// json_transformer.dart
class PublicationJsonTransformer {
  static Map<String, dynamic> transformFromReadiumTS(Map<String, dynamic> raw) {
    return {
      'metadata': _transformMetadata(raw['metadata']),
      'readingOrder': _transformLinks(raw['readingOrder']),
      'resources': _transformLinks(raw['resources']),
      // ...
    };
  }

  static Map<String, dynamic> _transformMetadata(Map<String, dynamic>? raw) {
    // Extracted logic
  }

  static List<Map<String, dynamic>> _transformLinks(List? raw) {
    // Extracted logic
  }
}
```

#### 4.1.5 reader_widget.dart (341 lines)

**Refactoring plan**:
```
flureadium/lib/src/reader/
├── reader_widget.dart       # Main widget (~150 lines)
├── reader_lifecycle.dart    # Lifecycle management mixin (~80 lines)
├── wakelock_manager.dart    # Wakelock handling (~50 lines)
└── orientation_handler.dart # Orientation change handling (~50 lines)
```

**Use mixins for separation**:
```dart
// reader_lifecycle.dart
mixin ReaderLifecycleMixin<T extends StatefulWidget> on State<T> {
  bool _isReaderCreated = false;

  void onReaderCreated() {
    _isReaderCreated = true;
    // ...
  }

  void onReaderClosed() {
    _isReaderCreated = false;
    // ...
  }
}

// reader_widget.dart
class _ReadiumReaderWidgetState extends State<ReadiumReaderWidget>
    with ReaderLifecycleMixin, WakelockMixin {
  // Cleaner, focused implementation
}
```

### 4.2 Resolve TODO Comments

**Strategy**: Convert TODOs to GitHub Issues or resolve them.

#### Critical TODOs (resolve now):

| File | TODO | Action |
|------|------|--------|
| reader_widget.dart:124 | "Find a better way to handle page alignment" | Investigate and fix or document limitation |
| reader_widget.dart:309 | "Remove this workaround when underlying issue fixed" | Track upstream issue, add GitHub issue reference |
| flureadium_web.dart | Multiple unimplemented methods | Implement or mark as unsupported |

#### Non-critical TODOs (convert to issues):

Create GitHub issues with labels:
- `enhancement` for feature requests
- `tech-debt` for refactoring needs
- `documentation` for doc improvements

**Template**:
```markdown
## TODO: [Brief description]

**Source**: `path/to/file.dart:line`

**Context**:
[Original TODO comment]

**Proposed solution**:
[Describe what needs to be done]

**Related**:
- Link to any upstream issues
- Link to related code
```

### 4.3 Implement JSON Code Generation

**Current**: Manual `fromJson`/`toJson` implementations throughout.

**Target**: Use `json_serializable` for type-safe, maintainable serialization.

#### Setup

Add to `pubspec.yaml`:
```yaml
dependencies:
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.8.0
```

#### Migration Pattern

**Before** (manual):
```dart
class Locator {
  final String href;
  final String type;
  final Locations? locations;

  factory Locator.fromJson(Map<String, dynamic> json) {
    return Locator(
      href: json['href'] as String,
      type: json['type'] as String,
      locations: json['locations'] != null
          ? Locations.fromJson(json['locations'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'href': href,
    'type': type,
    if (locations != null) 'locations': locations!.toJson(),
  };
}
```

**After** (generated):
```dart
import 'package:json_annotation/json_annotation.dart';

part 'locator.g.dart';

@JsonSerializable()
class Locator {
  final String href;
  final String type;
  final Locations? locations;

  const Locator({
    required this.href,
    required this.type,
    this.locations,
  });

  factory Locator.fromJson(Map<String, dynamic> json) => _$LocatorFromJson(json);
  Map<String, dynamic> toJson() => _$LocatorToJson(this);
}
```

#### Migration Order

1. Leaf models first (no dependencies): `LocatorText`, `DomRange`, `Locations`
2. Composite models: `Locator`, `Link`, `Contributor`
3. Complex models: `Metadata`, `Publication`
4. Preferences: `EPUBPreferences`, `TTSPreferences`, `AudioPreferences`

### 4.4 Standardize Error Handling

**Current issues**:
- Inconsistent error propagation
- Some errors silently ignored
- Mixed use of exceptions and error streams

**Standardization**:

```dart
// Define error categories
enum FlureadiumErrorCategory {
  publication,  // Opening, parsing errors
  navigation,   // Go to locator, link errors
  playback,     // TTS, audio errors
  network,      // HTTP, streaming errors
  platform,     // Native bridge errors
}

// Unified error model
class FlureadiumError {
  final FlureadiumErrorCategory category;
  final String code;
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  bool get isRecoverable => _recoverableCodes.contains(code);
}

// Error handling pattern
try {
  await flureadium.openPublication(url);
} on OpeningReadiumException catch (e) {
  if (e.type == OpeningExceptionType.notFound) {
    showNotFoundDialog();
  } else if (e.type == OpeningExceptionType.forbidden) {
    promptForCredentials();
  } else {
    showGenericError(e.message);
  }
}
```

### 4.5 Improve Logging

**Current**: Limited logging with `R2Log`.

**Improvements**:

```dart
// logging.dart
import 'package:fimber/fimber.dart';

class FlureadiumLogger {
  static final _logger = FimberLog('Flureadium');

  static void publication(String message, {Object? error}) {
    _logger.i('[Publication] $message', ex: error);
  }

  static void navigation(String message, {Object? error}) {
    _logger.d('[Navigation] $message', ex: error);
  }

  static void playback(String message, {Object? error}) {
    _logger.d('[Playback] $message', ex: error);
  }

  static void error(String message, Object error, StackTrace? stack) {
    _logger.e(message, ex: error, stacktrace: stack);
  }
}

// Usage
FlureadiumLogger.publication('Opening: $url');
FlureadiumLogger.navigation('Go to locator: ${locator.href}');
FlureadiumLogger.error('Failed to open', exception, stackTrace);
```

---

## Refactoring Checklist

For each refactoring:

- [ ] Write/update tests first (from Milestone 1)
- [ ] Extract to new file(s)
- [ ] Update imports throughout codebase
- [ ] Run full test suite
- [ ] Update documentation if public API changes
- [ ] Commit with descriptive message

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Files >300 lines | 0 |
| TODO comments | 0 (converted to issues) |
| JSON serialization | Code-generated |
| All tests passing | 100% |
| No analyzer warnings | 0 |

---

## Estimated Impact

| Area | Before | After |
|------|--------|-------|
| Largest file | 488 lines | <200 lines |
| Avg file size | ~150 lines | ~100 lines |
| Manual JSON code | ~1500 lines | ~200 lines |
| Tech debt items | 17+ | 0 (tracked in issues) |

---

*Part of [Flureadium Analysis](ANALYSIS.md)*
