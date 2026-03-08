# 模块：reader

## 模块目的

提供沉浸式书籍阅读体验，使用 Readium SDK (flureadium) 进行 EPUB 渲染与分页，支持点击显隐上下控制层、章节目录/笔记/进度/亮度/字体五入口面板，以及按书保存阅读偏好。

## 边界

### In

- 打开书籍并恢复上次阅读位置（通过 Readium Locator JSON）
- 使用 Readium SDK 原生分页与渲染
- 点击正文显隐顶部/底部控制层
- 顶部右侧三点打开图书信息型 bottom sheet
- 底部五入口打开章节/笔记/进度/亮度/字体面板
- 阅读偏好（字体、边距、行距、颜色、亮度）按书持久化
- 高亮创建与回显（通过 Readium Decoration API）

### Out

- 听书/AI/翻译真实能力
- 三点面板中功能按钮的完整业务（当前为占位）
- 真实阅读时长统计（当前为 UI 占位值）
- TXT/PDF 等非 EPUB 格式支持

## 核心流程

1. 根据 `bookId` 打开书籍，**并行**加载图书元数据、阅读进度（Locator JSON）、该书偏好设置（`Future.wait`）。
2. 通过 `PublicationCacheService.getOrOpen(epubFilePath)` 打开 EPUB 文件。若同一本书被再次打开，直接复用缓存的 Publication，跳过原生 EPUB 解析（节省 ~800ms）。
3. 恢复保存的 Locator 位置（如有），通过 `flureadium.goToLocator(locator)` 跳转。
4. 应用用户偏好设置到 Readium（`setEPUBPreferences`）。
5. 监听 Readium 位置变化（`onTextLocatorChanged`），更新进度并定时持久化。
6. 点击正文切换上下控制层显隐；顶部三点与底部五入口面板按既定交互显示。
7. 亮度/字体设置立即作用于 Readium 并写入 `reader_preferences`；离页时 flush 进度。
8. 离开 ReaderPage 时**不关闭 Publication**（保留缓存）。App 进入后台或终止时由 `ImmersedApp` 的生命周期监听器调用 `PublicationCacheService.evict()` 释放资源。

### Readium 渲染架构

```
导入层                          Readium SDK                      ReaderPage
EPUB → 拷贝到本地目录            原生 EPUB 解析与渲染              ReadiumReaderWidget
     → 存储 epubFilePath        ↓ 分页/滚动                      + 控制层 UI
                                ↓ Locator 回调                   + 高亮 Decoration
```

1. **导入层**：`BookImportService` 提取 EPUB 元数据（标题、作者、封面），EPUB 文件整体拷贝到本地 `booksDirectory`，存储 `epubFilePath`。
2. **Readium 层**：flureadium 包装 Readium SDK（iOS/Android 原生），处理 EPUB 解析、分页、渲染、位置追踪。
3. **UI 层**：`ReaderPage` 承载 `ReadiumReaderWidget` 并管理控制层、偏好面板等 Flutter UI。

### 位置追踪

- 使用 Readium Locator（EPUB CFI 格式）代替章节 + 字符偏移。
- Locator 包含 `href`（spine 位置）、`locations`（进度百分比）等字段。
- 通过 `onTextLocatorChanged` 流实时获取当前位置，定时持久化到 `reading_progress` 表。

### 高亮机制

- **创建**：从 Readium 选区获取 Locator 和选中文本，存储到 `highlights` 表。
- **回显**：通过 `flureadium.applyDecorations()` API 将高亮应用到 Readium 渲染层。
- 高亮位置基于 Readium Locator（CFI），跨设备/版本稳定。

## 关键状态与数据

- `ReaderState.book` — 当前图书实体
- `ReaderState.locatorJson` — 当前 Readium Locator JSON
- `ReaderState.bookPercent` — 阅读进度百分比
- `ReaderState.preferences` — 阅读偏好
- `ReaderState.isLoading / isReaderReady / isSaving`
- `ReadingProgressEntity(bookId, locatorJson, percent, updatedAt)`
- `ReaderPreferencesEntity(bookId, fontSize, pagePaddingLevel, lineHeightLevel, letterSpacing, textColor, backgroundColor, brightness, fontFamily, firstLineIndent, pageTurnMode)`
- `reader_preferences` 表（`book_id` 主键）
- `reading_progress` 表（`book_id` 主键，存储 `locator_json`）
- `PublicationCacheService` — 单例，缓存最近一次打开的 Publication（Dart 对象 + 原生状态）。仅在 app 进入后台或打开不同书时释放。
- **原生 Manifest 磁盘缓存** — 首次打开 EPUB 后，原生层（ReadiumReader / FlureadiumPlugin）将 manifest JSON 写入 `{epubPath}.manifest.json`。后续打开同一 EPUB 时直接从缓存重建 Publication（跳过 OPF 解析，节省 ~600ms）。缓存对 Dart 层完全透明。

## 交互与异常

- 默认显示正文，控制层默认隐藏。
- 单击正文后显示顶部/底部控制层，再次单击隐藏。
- 章节面板支持 Readium TOC 导航与章节跳转。
- 亮度通过阅读层遮罩实现，不调用系统亮度 API。
- 图书不存在或 EPUB 文件缺失时显示错误态。
- 偏好或进度保存失败时不阻断阅读流程。

## 验收标准

- 阅读页使用 Readium 原生渲染，支持点击显隐控制层。
- EPUB 富文本（粗体、斜体、标题、列表、图片等）正确渲染。
- 顶部仅保留返回 + 三点按钮。
- 底部存在五个入口并能弹出对应面板。
- 章节目录支持跳转。
- 亮度/字体设置实时生效且重启后可恢复。
- 阅读进度（Locator）重启后正确恢复。
- 高亮创建与回显功能正常。
- `flutter analyze` 通过。

## 非目标

- 不实现三点面板内"下载完成/自动翻页/书友想法"等真实业务链路。
- 不实现 AI/翻译/听书能力。
- 不实现真实阅读时长累计统计。
- 不支持 TXT/PDF 等非 EPUB 格式（本次重构范围）。
- 不兼容旧版阅读进度/高亮数据（破坏式重构）。
