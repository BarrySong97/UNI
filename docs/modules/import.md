# 模块：import

## 模块目的
支持本地 EPUB 文件导入到书架，提取元数据（标题、作者、封面）并存储 EPUB 文件路径。

## 边界
### In
- 文件选择
- 格式识别（仅 EPUB）
- 元数据提取（标题、作者、封面）
- EPUB 文件拷贝到本地目录
- 书籍入库

### Out
- 阅读器渲染（由 Readium SDK 处理）
- 章节解析（由 Readium SDK 处理）
- 划线逻辑
- 远程下载与版权管理

## 核心流程
1. 用户选择本地 EPUB 文件。
2. `BookImportService` 验证文件格式为 EPUB。
3. 提取 EPUB 元数据：
   - 解析 OPF 文件获取标题、作者
   - 提取封面图片转为 data URL
4. 生成 `ImportedBookDraft`（包含元数据和 `coverUrl`）。
5. `LibraryStore` 将 EPUB 文件拷贝到 `booksDirectory`。
6. 解压 EPUB 到 `books/{bookId}/` 目录，供原生层 `DirectoryContainer` 使用（加速后续打开）。
7. 基于封面提取 `profileBgColor`（用于书架渐变背景）。
7. 写入 `BookRepository`，存储 `epubFilePath` 字段。
8. 刷新书架并提示导入结果。

## 关键状态与数据
- `BookImportService.supportedExtensions` = `{'epub'}`
- `ImportedBookDraft`（title, author, sourceType, sourcePath, format, coverUrl）
- `LibraryState.isImporting / lastImportMessage`
- `BookEntity.epubFilePath`（EPUB 文件本地路径）
- `BookEntity.profileBgColor`（导入时提取并入库）

## 交互与异常
- 不支持格式（非 EPUB）时抛出 `UnsupportedError`。
- 文件不存在或读取失败时抛出 `FileSystemException`。
- EPUB 元数据缺失时回退到文件名（标题）/ 'Unknown'（作者）。
- EPUB 封面缺失或解析失败时不阻断导入，`coverUrl` 为 null。
- 封面存在但取色失败时不阻断导入，`profileBgColor` 可为空。

## 验收标准
- EPUB 导入后可在书架看到并进入阅读。
- EPUB 导入后若包含封面资源，书架展示真实封面。
- EPUB 导入优先使用 metadata 中的标题/作者；缺失时回退文件名/Unknown。
- 重启应用后导入书籍仍存在（Android/iOS/macOS）。
- 导入成功/失败都有反馈。
- 非 EPUB 格式明确报错。
- `flutter analyze` 通过。

## 非目标
- 不支持 TXT/PDF/MOBI/AZW3 等非 EPUB 格式（本次重构范围）。
- 不做 DRM 处理。
- 不做大文件后台任务队列。
- 不解析章节内容（由 Readium SDK 在阅读时处理）。
