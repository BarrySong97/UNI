# Milestone 5: Pub.dev Publication Readiness

**Priority**: Medium
**Depends on**: Milestones 1-4 (all prior work)

---

## Objective

Prepare flureadium for publication on pub.dev with maximum quality score and professional presentation.

---

## Current State

| Requirement | Status |
|-------------|--------|
| Package naming | Available |
| Dart SDK constraint | ✅ >=3.8.0 |
| Null safety | ✅ Complete |
| License | Needs verification |
| Tests | ❌ Incomplete |
| Documentation | ❌ Incomplete |
| Example | ✅ Present |
| CHANGELOG | Needs update |

**Estimated current pana score**: 80-90/140

---

## Tasks

### 5.1 Package Metadata

#### flureadium_platform_interface/pubspec.yaml

```yaml
name: flureadium_platform_interface
description: >
  A common platform interface for the flureadium plugin.
  This package provides the shared types and platform interface
  that platform-specific implementations depend on.
version: 1.0.0
homepage: https://github.com/user/flureadium
repository: https://github.com/user/flureadium
issue_tracker: https://github.com/user/flureadium/issues
documentation: https://pub.dev/documentation/flureadium_platform_interface/latest/

topics:
  - readium
  - epub
  - ebook
  - reader
  - audiobook

screenshots:
  - description: 'EPUB reader with customizable typography'
    path: screenshots/epub_reader.png
  - description: 'Audiobook playback controls'
    path: screenshots/audiobook_player.png

funding:
  - https://github.com/sponsors/user

environment:
  sdk: '>=3.8.0 <4.0.0'
  flutter: '>=3.24.0'
```

#### flureadium/pubspec.yaml

```yaml
name: flureadium
description: >
  A comprehensive Flutter plugin for reading EPUB ebooks, audiobooks,
  and comics using the Readium toolkits. Supports Android, iOS, macOS, and Web.
version: 1.0.0
homepage: https://github.com/user/flureadium
repository: https://github.com/user/flureadium
issue_tracker: https://github.com/user/flureadium/issues
documentation: https://pub.dev/documentation/flureadium/latest/

topics:
  - readium
  - epub
  - ebook
  - reader
  - audiobook

screenshots:
  - description: 'EPUB reader with customizable typography'
    path: screenshots/epub_reader.png
  - description: 'Text-to-speech with word highlighting'
    path: screenshots/tts_reading.png
  - description: 'Audiobook playback controls'
    path: screenshots/audiobook_player.png

funding:
  - https://github.com/sponsors/user

platforms:
  android:
  ios:
  macos:
  web:

environment:
  sdk: '>=3.8.0 <4.0.0'
  flutter: '>=3.24.0'
```

### 5.2 License Verification

**Current**: Check existing LICENSE file.

**Requirements**:
- Must be OSI-approved license
- Recommended: BSD-3-Clause or MIT for Flutter plugins
- Must be compatible with Readium (BSD-3-Clause)

**LICENSE file** (if BSD-3-Clause):
```
BSD 3-Clause License

Copyright (c) 2024, [Author Name]
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### 5.3 CHANGELOG Preparation

**File**: `flureadium/CHANGELOG.md`

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-XX-XX

### Added
- Initial stable release
- EPUB reading with customizable typography
- Audiobook playback with background audio support
- Text-to-speech with voice selection
- Media overlay support for synchronized audio
- Highlighting and bookmark decorations
- Cross-platform support: Android, iOS, macOS, Web

### Platform Requirements
- Android: minSdkVersion 24
- iOS: 13.4+
- macOS: 10.15+
- Web: Modern browsers with ES6 support

### Dependencies
- Readium Kotlin Toolkit 3.1.2 (Android)
- Readium Swift Toolkit 3.5.0 (iOS/macOS)
- Readium TypeScript Toolkit (Web)

## [0.9.0] - 2026-XX-XX (Pre-release)

### Added
- Beta release for testing
- Core EPUB functionality
- TTS integration
- Basic audiobook support

### Changed
- Migrated from flutter_readium fork
- Updated to Readium 3.x toolkits
- Modernized Dart API with null safety

### Fixed
- Various stability improvements
```

### 5.4 Screenshots

Create high-quality screenshots for pub.dev:

```
flureadium/
├── screenshots/
│   ├── epub_reader.png      # 1284x2778 (iPhone 14 Pro Max)
│   ├── tts_reading.png      # 1284x2778
│   ├── audiobook_player.png # 1284x2778
│   └── settings.png         # 1284x2778 (optional)
```

**Screenshot requirements**:
- PNG format
- Device frames optional but recommended
- Light/dark mode variants helpful
- Max 10 screenshots

### 5.5 Platform Compatibility Matrix

Document in README and pub.dev description:

| Feature | Android | iOS | macOS | Web |
|---------|---------|-----|-------|-----|
| EPUB visual reading | ✅ | ✅ | ✅ | ✅ |
| PDF reading | ✅ | ✅ | ✅ | ❌ |
| Text-to-speech | ✅ | ✅ | ✅ | ❌ |
| Audiobook playback | ✅ | ✅ | ✅ | ⚠️ |
| Media overlays | ✅ | ✅ | ✅ | ❌ |
| Highlights/bookmarks | ✅ | ✅ | ✅ | ✅ |
| Background audio | ✅ | ✅ | ✅ | N/A |
| Offline reading | ✅ | ✅ | ✅ | ✅ |

Legend: ✅ Supported | ⚠️ Partial | ❌ Not supported | N/A Not applicable

### 5.6 Pre-Publication Checklist

#### Code Quality
- [ ] All tests passing (`flutter test`)
- [ ] No analyzer warnings (`flutter analyze --fatal-warnings`)
- [ ] Code formatted (`dart format --set-exit-if-changed .`)
- [ ] No TODO comments in release code

#### Documentation
- [ ] All public APIs documented
- [ ] README complete with examples
- [ ] CHANGELOG up to date
- [ ] CONTRIBUTING.md present
- [ ] LICENSE file verified

#### Package Structure
- [ ] pubspec.yaml metadata complete
- [ ] Screenshots prepared
- [ ] Example app working on all platforms
- [ ] Dependencies pinned appropriately

#### Publication
- [ ] `dart pub publish --dry-run` succeeds
- [ ] Pana score ≥120/140
- [ ] Version numbers consistent across packages
- [ ] Git tag created

### 5.7 Publication Commands

```bash
# Verify packages before publishing
cd flureadium_platform_interface
flutter pub get
dart pub publish --dry-run

cd ../flureadium
flutter pub get
dart pub publish --dry-run

# Run pana locally
dart pub global activate pana
pana flureadium_platform_interface
pana flureadium

# Publish (platform interface first!)
cd flureadium_platform_interface
dart pub publish

# Wait for pub.dev to index, then:
cd ../flureadium
# Update dependency to published version
dart pub publish
```

### 5.8 Post-Publication

#### Monitor
- Watch pub.dev for score updates (may take hours)
- Check for any analyzer warnings on pub.dev
- Monitor GitHub issues for user reports

#### Announce
- Update project README with pub.dev badges
- Announce on Flutter communities:
  - r/FlutterDev
  - Flutter Discord
  - Twitter/X with #Flutter hashtag

#### Maintain
- Respond to issues promptly
- Release patch versions for critical bugs
- Plan next minor/major releases

---

## Pana Score Optimization

Target: **≥120/140 points**

| Category | Points | How to Achieve |
|----------|--------|----------------|
| Follow Dart conventions | 30 | Proper formatting, naming |
| Provide documentation | 20 | API docs, README, examples |
| Platform support | 20 | Declare all platforms |
| Pass static analysis | 30 | Zero warnings/errors |
| Support up-to-date deps | 20 | Current dependencies |
| Support null safety | 20 | Already complete |

### Common Score Deductions

| Issue | Deduction | Fix |
|-------|-----------|-----|
| Missing documentation | -10 to -20 | Add dartdoc comments |
| Outdated dependencies | -5 to -10 | Update pubspec.yaml |
| Format issues | -5 | Run `dart format` |
| Analyzer warnings | -10 to -20 | Fix all warnings |
| Missing example | -10 | Add example/ directory |

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Pana score | ≥120/140 |
| Pub.dev likes | Track post-launch |
| GitHub stars | Track post-launch |
| Open issues | <10 within first month |
| Test coverage | >70% |

---

## Timeline Suggestion

| Week | Activity |
|------|----------|
| 1 | Final code review, fix any issues |
| 2 | Documentation completion |
| 3 | Screenshots, metadata finalization |
| 4 | Dry-run publishing, final testing |
| 5 | **Publish to pub.dev** |
| 6+ | Monitor, respond to feedback |

---

*Part of [Flureadium Analysis](ANALYSIS.md)*
