# Settings Module

## Purpose

Settings page providing AI configuration, TTS configuration, quick TTS testing,
and app information links. Includes per-language AI explain behavior controls
used by Reader.

## Boundary

### In Scope
- Account display (avatar, name, membership info)
- AI settings rows (Explanation Detail, Explanation Language, Vocabulary Level, API Key)
- TTS settings entry and dedicated TTS quick-test page for word/phrase checks
- Per-language AI explain mode toggle:
  - Structured mode (default): Reader uses built-in explain cards.
  - Custom prompt mode: Reader renders free-form markdown generated from user prompt.
- Per-language custom prompt template editing with placeholders
- Test explain preview sheet with non-reader long-press pronunciation actions (`IPA` or `AI`, `Pronounce`, `Copy`) inside previewed explanation markdown
- About section links (Feedback, Email, Social Media, Help, FAQ)

### Out of Scope
- Authentication / login flow
- Actual AI configuration logic
- Deep-link handling for about items

## Core Flow

1. User navigates to Settings tab via bottom floating tab bar
2. Page renders three sections: AI, TTS, ABOUT
3. TTS section exposes both full configuration and a lightweight quick-test page
4. Each settings row opens its detail screen or sheet

## Key State & Data

- Currently UI-only with hardcoded mock data
- No state management required at this stage
- `AiLanguageConfig` persistence in `SharedPreferences`:
  - `model`
  - `detail`
  - `explanationLanguage`
  - `customPrompt`
  - `customPromptModeEnabled`
  - `vocabularyLevel`

## Interaction & Exceptions

- TTS voice catalog is now a built-in offline Kokoro catalog for English (`en_US` / `en_GB`) instead of the previous Piper voice list. Settings no longer depends on fetching a remote voice catalog before showing voice choices.
- `AiLanguageConfig` is the code object behind per-language Explanation Settings. `explanationLanguage` only controls the response output language, while `vocabularyLevel` belongs to the source/book language config.
- Vocabulary Level currently ships only for English. English exposes `CET4`, `CET6` (default), `IELTS`, `TOEFL`, and `GRE`. Non-English languages keep the data-model extension point but do not show a Vocabulary Level UI yet.
- Vocabulary Level affects only built-in structured explain prompts. Custom prompt mode ignores it and continues to use the user-authored prompt plus existing detail/language instructions.
- Changing Vocabulary Level does not invalidate existing explain cache entries. If the user refreshes an explanation, Reader regenerates it with the current Vocabulary Level and overwrites the same cache key.
- All English voice options share the same Kokoro archive on disk. Downloading one Kokoro English voice makes the other Kokoro English voices immediately available because they point at the same extracted model bundle with different default speaker IDs.
- Settings voice preview uses the same shared TTS playback path as Reader: each utterance gets its own temp wav path and the engine deletes owned temp files on stop/completion.
- Settings includes a dedicated TTS quick-test page so short words and phrases can be retried without opening Reader. The page reuses the shared `TtsService`, configured voices, and playback state.
- The TTS quick-test page has its own temporary speed control. It defaults to the slowest test speed and only affects ad-hoc test playback, not the saved global playback setting.
- The settings test explain preview uses the shared non-reader pronunciation selection helper when app providers are available; if providers are absent, it falls back to plain selectable markdown rendering. When local phonetics and cached AI phonetics both miss, the shared toolbar still shows `Pronounce` and `Copy` and replaces the leading `IPA` slot with an `AI` button that can query the configured OpenAI-compatible endpoint on demand.

## Components

| Component | File | Description |
|-----------|------|-------------|
| `SettingsPage` | `lib/pages/settings/settings-page.dart` | Page layout composing all sections |
| `TtsTestPage` | `lib/components/settings/tts_test_page.dart` | Dedicated page for rapid TTS word/phrase testing |
| `SettingsAccountCard` | `lib/components/settings/settings-account-card.dart` | Account avatar + name card |
| `SettingsSectionLabel` | `lib/components/settings/settings-row.dart` | Uppercase section header label |
| `SettingsRow` | `lib/components/settings/settings-row.dart` | Icon + label + value + chevron row |

## Design Tokens

- Common: `cardRadius`, `cardBg`
- Settings-specific: `settingsAccountAvatarSize`, `settingsRowHeight`, `settingsRowIconContainerSize`, `settingsRowIconContainerRadius`, `settingsRowIconContainerBg`
- All font sizes reuse existing tokens (`headerLabelSize`, `bookTitleSize`, `bookAuthorSize`, `bookProfileActionSize`, `bookProfileMetaSize`)

## Acceptance Criteria

- [ ] Settings tab shows header with "IMMERSED" + "Settings"
- [ ] AI section shows configured AI explain entry
- [ ] TTS section shows both full TTS settings and a dedicated `TTS Test` entry
- [ ] TTS test page supports entering a word/phrase, picking a configured voice, adjusting a temporary test speed, and triggering speak/stop
- [ ] AI language config supports switching between structured mode and custom prompt mode
- [ ] English Explanation Settings exposes Vocabulary Level with `CET4`, `CET6`, `IELTS`, `TOEFL`, and `GRE`, defaulting to `CET6`
- [ ] Custom prompt is only editable/effective when custom prompt mode is enabled
- [ ] ABOUT section shows settings help/contact rows with chevrons
- [ ] Visual style matches shelf/library page patterns (colors, spacing, typography)
- [ ] `flutter analyze` passes with no errors
- [ ] `flutter test` passes with no regressions

## Non-Goals

- Functional settings persistence
- Navigation to detail screens
- User authentication integration
