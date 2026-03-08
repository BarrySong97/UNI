# Settings Module

## Purpose

Settings page providing user account info, AI configuration, and app information links.

## Boundary

### In Scope
- Account display (avatar, name, membership info)
- AI settings rows (Explanation Detail, Explanation Language, API Key)
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
- [ ] ABOUT section shows 5 rows with icons, labels, and chevrons
- [ ] Visual style matches shelf/library page patterns (colors, spacing, typography)
- [ ] `flutter analyze` passes with no errors
- [ ] `flutter test` passes with no regressions

## Non-Goals

- Functional settings persistence
- Navigation to detail screens
- User authentication integration
