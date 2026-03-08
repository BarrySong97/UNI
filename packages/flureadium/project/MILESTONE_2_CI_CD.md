# Milestone 2: CI/CD Pipeline

**Priority**: Critical
**Depends on**: Milestone 1 (Testing)

---

## Objective

Establish automated quality gates to prevent regressions, ensure code quality, and streamline the release process.

---

## Current State

- No CI/CD configuration exists
- No automated testing
- No automated code quality checks
- Manual release process

---

## Tasks

### 2.1 GitHub Actions Workflow for Testing

**File**: `.github/workflows/test.yml`

```yaml
name: Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test-platform-interface:
    name: Test Platform Interface
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: flureadium_platform_interface
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze --fatal-infos

      - name: Run tests
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: coverage/lcov.info
          flags: platform-interface

  test-main-package:
    name: Test Main Package
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: flureadium
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze --fatal-infos

      - name: Run tests
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: coverage/lcov.info
          flags: main-package
```

### 2.2 Android Build Verification

**File**: `.github/workflows/build-android.yml`

```yaml
name: Build Android

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    name: Build Android Example
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: flureadium/example
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Build APK
        run: flutter build apk --debug

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: android-debug-apk
          path: flureadium/example/build/app/outputs/flutter-apk/app-debug.apk
```

### 2.3 iOS Build Verification

**File**: `.github/workflows/build-ios.yml`

```yaml
name: Build iOS

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    name: Build iOS Example
    runs-on: macos-latest
    defaults:
      run:
        working-directory: flureadium/example
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true

      - name: Install CocoaPods
        run: |
          cd ios
          pod install --repo-update

      - name: Build iOS (no codesign)
        run: flutter build ios --debug --no-codesign
```

### 2.4 Web Build Verification

**File**: `.github/workflows/build-web.yml`

```yaml
name: Build Web

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    name: Build Web Example
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: flureadium/example
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Copy JS file
        run: dart run flureadium:copy_js_file web/

      - name: Build Web
        run: flutter build web

      - name: Upload Web Build
        uses: actions/upload-artifact@v4
        with:
          name: web-build
          path: flureadium/example/build/web/
```

### 2.5 Code Quality Checks

**File**: `.github/workflows/quality.yml`

```yaml
name: Code Quality

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  format:
    name: Check Formatting
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true

      - name: Check format - platform interface
        run: dart format --set-exit-if-changed flureadium_platform_interface/lib

      - name: Check format - main package
        run: dart format --set-exit-if-changed flureadium/lib

  analyze:
    name: Static Analysis
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true

      - name: Get dependencies - platform interface
        working-directory: flureadium_platform_interface
        run: flutter pub get

      - name: Get dependencies - main package
        working-directory: flureadium
        run: flutter pub get

      - name: Analyze - platform interface
        working-directory: flureadium_platform_interface
        run: flutter analyze --fatal-infos --fatal-warnings

      - name: Analyze - main package
        working-directory: flureadium
        run: flutter analyze --fatal-infos --fatal-warnings

  pub-score:
    name: Pub.dev Score Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true

      - name: Install pana
        run: dart pub global activate pana

      - name: Check platform interface score
        working-directory: flureadium_platform_interface
        run: |
          flutter pub get
          pana --no-warning --exit-code-threshold 100

      - name: Check main package score
        working-directory: flureadium
        run: |
          flutter pub get
          pana --no-warning --exit-code-threshold 100
```

### 2.6 Release Workflow

**File**: `.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  validate:
    name: Validate Release
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true

      - name: Validate version consistency
        run: |
          TAG_VERSION=${GITHUB_REF#refs/tags/v}
          PI_VERSION=$(grep 'version:' flureadium_platform_interface/pubspec.yaml | cut -d' ' -f2)
          MAIN_VERSION=$(grep 'version:' flureadium/pubspec.yaml | cut -d' ' -f2)

          if [ "$TAG_VERSION" != "$PI_VERSION" ] || [ "$TAG_VERSION" != "$MAIN_VERSION" ]; then
            echo "Version mismatch!"
            echo "Tag: $TAG_VERSION"
            echo "Platform Interface: $PI_VERSION"
            echo "Main Package: $MAIN_VERSION"
            exit 1
          fi

      - name: Validate CHANGELOG
        run: |
          TAG_VERSION=${GITHUB_REF#refs/tags/v}
          if ! grep -q "## $TAG_VERSION" flureadium/CHANGELOG.md; then
            echo "CHANGELOG.md missing entry for version $TAG_VERSION"
            exit 1
          fi

  publish-dry-run:
    name: Publish Dry Run
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true

      - name: Dry run - platform interface
        working-directory: flureadium_platform_interface
        run: |
          flutter pub get
          dart pub publish --dry-run

      - name: Dry run - main package
        working-directory: flureadium
        run: |
          flutter pub get
          dart pub publish --dry-run

  create-release:
    name: Create GitHub Release
    needs: publish-dry-run
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Extract changelog
        id: changelog
        run: |
          TAG_VERSION=${GITHUB_REF#refs/tags/v}
          CHANGELOG=$(sed -n "/## $TAG_VERSION/,/## [0-9]/p" flureadium/CHANGELOG.md | sed '$d')
          echo "changelog<<EOF" >> $GITHUB_OUTPUT
          echo "$CHANGELOG" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          body: ${{ steps.changelog.outputs.changelog }}
          draft: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 2.7 Dependabot Configuration

**File**: `.github/dependabot.yml`

```yaml
version: 2
updates:
  - package-ecosystem: "pub"
    directory: "/flureadium_platform_interface"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5

  - package-ecosystem: "pub"
    directory: "/flureadium"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 3
```

---

## Workflow Diagram

```
                    ┌─────────────────┐
                    │   Push/PR       │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│  Test Suite    │  │  Code Quality  │  │  Build Checks  │
│  - Unit tests  │  │  - Format      │  │  - Android     │
│  - Coverage    │  │  - Analyze     │  │  - iOS         │
└───────┬────────┘  │  - Pub score   │  │  - Web         │
        │           └───────┬────────┘  └───────┬────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │  All Passed?  │
                    └───────┬───────┘
                            │ Yes
                            ▼
                    ┌───────────────┐
                    │ Merge Allowed │
                    └───────────────┘
```

---

## Branch Protection Rules

Configure in GitHub repository settings:

**For `main` branch:**
- Require status checks to pass:
  - `Test Platform Interface`
  - `Test Main Package`
  - `Check Formatting`
  - `Static Analysis`
  - `Build Android Example`
- Require branches to be up to date
- Require pull request reviews (1 reviewer)
- Do not allow bypassing the above settings

---

## Success Criteria

| Requirement | Target |
|-------------|--------|
| All workflows created | 6 files |
| Tests run on every PR | Automated |
| Build verification | Android, iOS, Web |
| Format/analyze checks | Blocking |
| Dependabot enabled | Weekly updates |
| Branch protection | Configured |

---

## Files to Create

```
.github/
├── workflows/
│   ├── test.yml
│   ├── build-android.yml
│   ├── build-ios.yml
│   ├── build-web.yml
│   ├── quality.yml
│   └── release.yml
└── dependabot.yml
```

---

*Part of [Flureadium Analysis](ANALYSIS.md)*
