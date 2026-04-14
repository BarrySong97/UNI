# Settings Module

## Purpose

Settings page providing user account info, AI configuration, and app information links.
Includes per-language AI explain behavior controls used by Reader.

## Boundary

### In Scope
- Account display (avatar, name, membership info)
- AI settings rows (Explanation Detail, Explanation Language, API Key)
- Per-language AI explain mode toggle:
  - Structured mode (default): Reader uses built-in explain cards.
  - Custom prompt mode: Reader renders free-form markdown generated from user prompt.
- Per-language custom prompt template editing with placeholders
- Test explain preview sheet with non-reader long-press pronunciation actions (`IPA`, `Pronounce`, `Copy`) inside previewed explanation markdown
- About section links (Feedback, Email, Social Media, Help, FAQ)

### Out of Scope
- Authentication / login flow
- Actual AI configuration logic
- Deep-link handling for about items

## Core Flow

1. User navigates to Settings tab via bottom floating tab bar
2. Page renders three sections: ACCOUNT, AI, ABOUT
3. Each setting row is tappable (navigation-ready, no functionality yet)

## Key State & Data

- Currently UI-only with hardcoded mock data
- No state management required at this stage
- `AiLanguageConfig` persistence in `SharedPreferences`:
  - `model`
  - `detail`
  - `explanationLanguage`
  - `customPrompt`
  - `customPromptModeEnabled`

## Interaction & Exceptions

- TTS voice catalog loading is network-first with cache/bundled fallback.
- If remote catalog fetch times out or network is unavailable, settings should continue to use cached/bundled voices without blocking UI initialization.
- The settings test explain preview uses the shared non-reader pronunciation selection helper when app providers are available; if providers are absent, it falls back to plain selectable markdown rendering. When phonetics lookup returns empty, the shared toolbar still shows `Pronounce` and `Copy` but hides the `IPA` label.

## Components

| Component | File | Description |
|-----------|------|-------------|
| `SettingsPage` | `lib/pages/settings/settings-page.dart` | Page layout composing all sections |
| `SettingsAccountCard` | `lib/components/settings/settings-account-card.dart` | Account avatar + name card |
| `SettingsSectionLabel` | `lib/components/settings/settings-row.dart` | Uppercase section header label |
| `SettingsRow` | `lib/components/settings/settings-row.dart` | Icon + label + value + chevron row |

## Design Tokens

- Common: `cardRadius`, `cardBg`
- Settings-specific: `settingsAccountAvatarSize`, `settingsRowHeight`, `settingsRowIconContainerSize`, `settingsRowIconContainerRadius`, `settingsRowIconContainerBg`
- All font sizes reuse existing tokens (`headerLabelSize`, `bookTitleSize`, `bookAuthorSize`, `bookProfileActionSize`, `bookProfileMetaSize`)

## Acceptance Criteria

- [ ] Settings tab shows header with "IMMERSED" + "Settings" + avatar
- [ ] ACCOUNT section displays card with avatar circle, name, subtitle, edit icon
- [ ] AI section shows 3 rows with icons, labels, values, and chevrons
- [ ] AI language config supports switching between structured mode and custom prompt mode
- [ ] Custom prompt is only editable/effective when custom prompt mode is enabled
- [ ] ABOUT section shows 5 rows with icons, labels, and chevrons
- [ ] Visual style matches shelf/library page patterns (colors, spacing, typography)
- [ ] `flutter analyze` passes with no errors
- [ ] `flutter test` passes with no regressions

## Non-Goals

- Functional settings persistence
- Navigation to detail screens
- User authentication integration
