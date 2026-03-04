# 模块：reader

## 模块目的

提供沉浸式书籍阅读体验，支持左右滑动分页、点击显隐上下控制层、章节目录/笔记/进度/亮度/字体五入口面板，以及按书保存阅读偏好与分页缓存。

## 边界

### In

- 打开书籍并恢复上次阅读位置（章节 + 章节内偏移）
- 使用 `PageView` 左右翻页阅读
- 点击正文显隐顶部/底部控制层
- 顶部右侧三点打开图书信息型 bottom sheet
- 底部五入口打开章节/笔记/进度/亮度/字体面板
- 阅读偏好（字体、边距、行距、颜色、亮度、首行缩进）按书持久化
- 分页结果按布局键（样式/视口/内容版本）持久化缓存
- 懒分页窗口预热（当前章前后 1 章）
- 进度拖拽（松手后跳转）

### Out

- 听书/AI/翻译真实能力
- 三点面板中功能按钮的完整业务（当前为占位）
- 真实阅读时长统计（当前为 UI 占位值）
- 复杂跨页选区高亮增强

## 核心流程

1. 根据 `bookId` 打开书籍，加载章节、阅读进度、该书偏好设置。
2. 构建布局键后优先读取分页缓存；命中则直接恢复页切片。
3. 缓存未命中时调用 `rebuildPagination`，使用 CJK 数学分页一次完成精确分页并写入缓存。
4. 分页按窗口（当前章前后 1 章）计算，翻页接近边缘时触发窗口预热。
5. 分页完成后立即触发全书目录指标计算（`ensureCatalogMetricsReady`）。
6. `PageView` 左右翻页时同步更新当前章节、页码、百分比和持久化进度。
7. 点击正文切换上下控制层显隐；顶部三点与底部五入口面板按既定交互显示。
8. 亮度/字体设置立即作用正文并写入 `reader_preferences`；离页时 flush 进度。

### 当前架构分层（2026-03）

- `ReaderStore` 负责会话编排与跨能力流程（打开书籍、翻页、跳转、保存进度）。
- `ReaderPaginationEngine` 负责分页算法与缓存切片恢复（从 store 中拆出）。
  - `ReaderFontMetrics` — 单字符测量结果（`charWidth / lineHeight / charsPerLine / linesPerPage`）。
  - `measureFontMetrics()` — 仅做 **1 次** TextPainter 调用，供整本书分页复用。
  - `buildPagesMath()` — CJK 数学扫描分页，O(总字符数)，全书目录计算从秒级降至毫秒级。
  - `buildPages()` — 保留作为降级兜底（非 CJK 或混合内容场景）。
- `ReaderCatalogMetricsService` 负责目录页码映射与缓存（从 store 中拆出）。
- `ReaderThemeService` 负责阅读样式参数映射（分页样式与渲染样式统一来源）。
- `ReaderPage` 负责 UI 组合与交互分发，不再内置排版规则常量。

## 关键状态与数据

- `ReaderState.book / chapters / chapter`
- `ReaderState.currentChapterIndex / charOffset / bookPercent`
- `ReaderState.currentPage / totalPages / currentPageIndex`
- `ReaderState.pageSlices`（分页结果）
- `ReaderState.windowChapterStart / windowChapterEnd / isWindowReady / paginationSource`
- `ReaderState.preferences`（阅读偏好）
- `ReadingProgressEntity(bookId, chapterId, charOffset, percent)`
- `ReaderPreferencesEntity(bookId, fontSize, pagePaddingLevel, lineHeightLevel, letterSpacing, textColor, backgroundColor, brightness, fontFamily, firstLineIndent, pageTurnMode)`
- `reader_preferences` 表（`book_id` 主键）
- `reader_pagination_cache` / `reader_pagination_slice` 表（分页缓存与页边界偏移）

## 交互与异常

- 默认显示正文与页码，控制层默认隐藏。
- 单击正文后显示顶部/底部控制层，再次单击隐藏。
- 章节面板支持搜索与章节跳转；每个章节项右侧显示按当前排版计算的整书章节起始页码。
- 章节面板采用“分页完成即就绪”策略：`rebuildPagination` 后立即触发 `ensureCatalogMetricsReady`，目录指标在首屏完成前就绪，无需 `--` 占位中间态。
- 右下角页码显示全书真实页码（`catalogChapterStartPages` + 当前窗口偏移 / `catalogTotalPages`）；目录指标未就绪时退回窗口相对页码。
- 当前阅读章节在目录中高亮，并在该章节项下显示“当前读到 x/y 页”；目录面板不提供书签入口。
- 进度面板滑条在 `onChangeEnd` 时执行跳页。
- 亮度通过阅读层遮罩实现，不调用系统亮度 API。
- 图书不存在或无章节时显示空态，不崩溃。
- 偏好或进度保存失败时不阻断阅读流程。
- 分页缓存写入失败时回退到实时分页，不阻断阅读流程。
- 目录分页指标计算失败时退回 `state.currentPage / totalPages` 窗口级页码，不阻断章节跳转。

## 验收标准

- 阅读页为左右分页阅读，且支持点击显隐控制层。
- 顶部仅保留返回 + 三点按钮。
- 底部存在五个入口并能弹出对应面板。
- 章节目录中每章展示标题与起始页码，支持跨窗口章节跳转，当前章节高亮并显示“当前读到 x/y”。
- 进度可拖拽并在松手后跳页。
- 亮度/字体设置实时生效且重启后可恢复。
- 同一书籍同一布局再次进入时优先命中分页缓存，首屏无明显阻塞。
- `flutter analyze` / `flutter test` 通过。

## 非目标

- 不实现三点面板内“下载完成/自动翻页/书友想法”等真实业务链路。
- 不实现 AI/翻译/听书能力。
- 不实现真实阅读时长累计统计。
