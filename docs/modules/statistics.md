# Statistics Module

## Purpose

Statistics page showing reading activity summaries, including reading time trends and books-read tracking, across configurable time periods (this month, this year, or a picked month).

## Boundary

### In Scope
- Period selection (this month / this year / pick a specific month)
- Reading Time tab: total time, average per day, daily minutes bar chart, yearly monthly bar chart, reading heatmap
- Books Read tab: qualified book count (progress >= 40% AND time >= 20 min), qualified book list, almost-there book list
- Data fetched from local database via `StatisticsStore`

### Out of Scope
- Reading session recording (handled by reader module)
- Goal setting or editing thresholds
- Social sharing or export of statistics

## Core Flow

1. User navigates to Statistics page (from library or other entry point)
2. `StatisticsStore` initializes with default period preset (`thisMonth`) and tab (`readingTime`)
3. Store queries database for the resolved time block and builds `ReadingTimeStatisticsData` / `BooksReadStatisticsData`. A separate query always fetches the past 365 days for the reading heatmap (`heatmapDailyStats`).
4. User can switch period via bottom-sheet picker (This Month / This Year / Pick Month)
5. User can toggle between Reading Time and Books Read tabs via segmented control

## Key State & Data

| State | Location | Description |
|-------|----------|-------------|
| `selectedTab` | `StatisticsStore` | Current tab: `readingTime` or `booksRead` |
| `selectedPeriodPreset` | `StatisticsStore` | `thisMonth`, `thisYear`, or `pickedMonth` |
| `pickedMonth` | `StatisticsStore` | Specific month when preset is `pickedMonth` |
| `readingTimeData` | `StatisticsStore` | Total seconds, avg/day, daily stats list |
| `booksReadData` | `StatisticsStore` | Qualified count, qualified books, almost-there books |
| `heatmapDailyStats` | `StatisticsStore` | Past-year daily stats for the reading heatmap (always 365 days) |

### Entities
- `StatisticsTimeBlock` — date range (start inclusive, end exclusive)
- `DailyReadingStat` — date + seconds
- `ReadingTimeStatisticsData` — aggregated reading time stats
- `QualifiedBookStat` / `AlmostThereBookStat` — per-book reading stats
- `BooksReadStatisticsData` — aggregated books-read stats

## Components

| Component | File | Description |
|-----------|------|-------------|
| `StatisticsPage` | `lib/pages/statistics/statistics-page.dart` | Main page layout |
| `StatisticsStore` | `lib/stores/statistics/statistics-store.dart` | Business logic & state |
| `StatisticsPageArguments` | `lib/pages/statistics/statistics-types.dart` | Navigation arguments |
| `StatisticsPeriodPreset` / `StatisticsTab` | `lib/pages/statistics/statistics-types.dart` | Enums |
| `statistics-entity.dart` | `lib/entities/statistics-entity.dart` | Data models |
| `statistics-design-tokens.dart` | `lib/shared/constants/statistics-design-tokens.dart` | Design tokens |

## Design Tokens

- Hero brown (`heroBrown`, `heroBrownDark`) for accent cards and highlights
- Chip styles (`chipBg`, `chipText`, `chipInactiveText`)
- Heatmap gradient (`heatmapEmpty`, `heatmapLevel1`–`heatmapLevel4`)
- Success indicators (`successBg`, `successText`)
- Common tokens reused: `pageBackground`, `textPrimary`, `textSecondary`, `softShadow`

## Acceptance Criteria

- [ ] Period selector shows current period and opens bottom-sheet picker
- [ ] Reading Time tab displays total time, avg/day, daily chart, and heatmap (heatmap always shows past year ~52 columns)
- [ ] Heatmap card shows title and legend on separate rows, with chart below
- [ ] Heatmap is placed above date filter and tab switch (period-independent)
- [ ] Heatmap cells are at least 10px and horizontally scrollable, defaulting to the rightmost (most recent) end
- [ ] Year view shows monthly aggregated bar chart
- [ ] Books Read tab shows qualified count hero card, qualified list, almost-there list
- [ ] Empty states display appropriate messages
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes

## Non-Goals

- Customizable qualification thresholds from UI
- Export / share statistics
- Cross-device sync of reading data
