# 模块：import

## 模块目的
支持本地文件导入到书架，并将可解析格式转换为章节数据。

## 边界
### In
- 文件选择
- 格式识别
- 导入草稿生成
- 书籍与章节入库

### Out
- 阅读器渲染
- 划线逻辑
- 远程下载与版权管理

## 核心流程
1. 用户选择本地文件。
2. `BookImportService` 根据扩展名分发解析逻辑。
3. 生成 `ImportedBookDraft`（包含可选 `coverUrl`）与章节草稿。
4. 导入阶段为每个章节提取并标准化章节标题（优先章节头/正文首行，缺失时回退默认标题）。
5. 导入阶段基于封面提取 `profileBgColor`（`#AARRGGBB`，提取失败可为空）。
6. 导入阶段按章节总字符数估算整本 `estimatedTotalPages` 并写入图书数据。
7. 写入 `BookRepository` / `ChapterRepository`（SQLite 持久化）。
8. 刷新书架并提示导入结果。

## 关键状态与数据
- `BookImportService.supportedExtensions`
- `ImportedBookDraft` / `ImportedChapterDraft`
- `LibraryState.isImporting / lastImportMessage`
- `ImportedBookDraft.coverUrl`（EPUB 提取到 data url）
- `BookEntity.profileBgColor`（导入时提取并入库）
- `BookEntity.estimatedTotalPages`（导入时估算并入库）

## 交互与异常
- 不支持格式时明确报错。
- 文件不存在或读取失败时提示失败。
- `pdf/mobi/azw3` 等当前可导入但用占位章节提示。
- EPUB 章节按 OPF spine 阅读顺序导入，章节标题优先取正文标题标签；提取失败回退默认标题（英文 `Chapter N` / 中文 `第N章`），不阻断导入。
- EPUB 章节标题优先级：TOC（`nav.xhtml` / `toc.ncx`）> 正文标题标签（`h1/h2/h3/title`）> 默认标题。
- EPUB 正文清洗保留段落边界（避免整章粘连为单段），并对超长章节按内容块进行分段导入（如 `Chapter 1 (2)`）。
- EPUB 封面缺失或解析失败时不阻断导入，封面回退占位。
- 封面存在但取色失败时不阻断导入，`profileBgColor` 可为空并由页面回退默认渐变。

## 验收标准
- `txt/epub` 导入后可读。
- 导入后每个章节都具备可展示的章节标题。
- 占位格式导入后可在书架看到。
- EPUB 导入后若包含封面资源，书架展示真实封面。
- EPUB 导入优先使用 metadata 中的标题/作者；缺失时回退文件名/Unknown。
- 重启应用后导入书籍/章节仍存在（Android/iOS/macOS）。
- 导入成功/失败都有反馈。
- `flutter analyze` / `flutter test` 通过。

## 非目标
- 不做 DRM 处理。
- 不做大文件后台任务队列。
