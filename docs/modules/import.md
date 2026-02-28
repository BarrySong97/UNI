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
3. 生成 `ImportedBookDraft` 与章节草稿。
4. 写入 `BookRepository` / `ChapterRepository`。
5. 刷新书架并提示导入结果。

## 关键状态与数据
- `BookImportService.supportedExtensions`
- `ImportedBookDraft` / `ImportedChapterDraft`
- `LibraryState.isImporting / lastImportMessage`

## 交互与异常
- 不支持格式时明确报错。
- 文件不存在或读取失败时提示失败。
- `pdf/mobi/azw3` 等当前可导入但用占位章节提示。

## 验收标准
- `txt/epub` 导入后可读。
- 占位格式导入后可在书架看到。
- 导入成功/失败都有反馈。
- `flutter analyze` / `flutter test` 通过。

## 非目标
- 不做 DRM 处理。
- 不做大文件后台任务队列。
