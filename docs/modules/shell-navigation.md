# Module: shell-navigation

## Module Purpose
Provide app-level page container and floating bottom tab navigation with state preservation across tabs.

## Boundary
### In
- Bottom floating tab bar navigation
- Page container management
- Tab state preservation (IndexedStack)
- Support nested routes from tab pages (e.g., `/book-detail`)

### Out
- Internal business logic (library/reader/highlight/import)
- Deep link complex routing

## Core Flow
1. App entry navigates to `MainTabShellPage`.
2. Uses `IndexedStack` to host `Shelf/Library/Settings`.
3. Floating tab bar at bottom displays icon-only tabs (Shelf is first tab).
4. Tap tab icon updates `currentIndex`.
5. Inactive page states remain preserved.
6. Library can navigate to `Book Profile` (`/book-detail`) and reader page.

## Key State & Data
- `MainTabShellPage.currentIndex`
- `IndexedStack.children`
- `FloatingTabBar.currentIndex`

## Tab Configuration
| Index | Page | Icon (Inactive) | Icon (Active) |
|-------|------|-----------------|---------------|
| 0 | Shelf (`ShelfPage`) | `library_books_outlined` | `library_books` |
| 1 | Library (`LibraryPage`) | `auto_stories_outlined` | `auto_stories` |
| 2 | Settings | `settings_outlined` | `settings` |

## Interaction & Exceptions
- Switching tabs does not lose state.
- Page transitions are smooth, no reinitialization of active pages.
- Floating tab bar uses dark background with white icons.
- Active tab shows filled icon with white background pill.

## Acceptance Criteria
- Three tabs switchable.
- State preserved when switching back.
- Route entry points to shell.
- `flutter analyze` / `flutter test` passes.

## Non-Goals
- Multi-layer nested route guards not implemented.
- Dynamic tab configuration not supported.
