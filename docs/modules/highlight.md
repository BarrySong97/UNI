# 模块：highlight

## 模块目的
在 Canvas Reader 中提供持久化标注能力。当前只启用 `mark` 类型：用户在 Reader 里选中文本后可通过 Tooltip 创建、编辑、删除 mark，并为 mark 添加多条 notes、选择颜色与样式（`Highlight` / `Underline`）。后续支持基于同一套 annotation 数据结构扩展 bookmark 等类型。

## 边界
### In
- 在 Canvas Reader 中根据当前 `CrossPageSelection` 创建 `mark`
- 在 Reader controls 中打开 marks 列表侧边面板
- 将选区映射为稳定锚点并持久化到 SQLite `annotations` 表
- 打开书籍后按章节恢复 annotation，并在 Reader 中重新渲染标记区域
- 从 marks 列表点击后跳转到对应正文位置，并支持返回原阅读位置
- 删除图书时级联删除该书的 annotations
- 维护 annotation 与 annotation notes 的 repository / store / DTO / DB schema
- 记住每本书最后一次使用的 mark 颜色与样式默认值

### Out
- note 编辑 UI
- 多色主题管理
- 云同步 / 协作批注
- 与旧 Readium Locator / CFI 模型共存

## 核心流程
1. 用户在 Canvas Reader 中长按选中文本，生成 `CrossPageSelection`。
2. 点击 Tooltip 的 `Mark` 会立即创建 mark；点击 `Note` 会打开 Weread 风格底部 composer；点击已有 mark 或 `Edit` 会打开紧凑的 mark style bar。
3. `SelectionToAnnotationMapper` 将选区按 block 分段，生成 `AnnotationAnchorV1`：
   - `chapterIndex / chapterHref`
   - `blockIndex`
   - `startOffset / endOffset`
   - `quoteText / prefixText / suffixText`
   - `blockTextHash`
4. 创建前先检测与现有 annotations 的关系：
   - 完全相同范围：拦截并提示 `Already marked`
   - 任意重叠：拦截并提示 `Overlaps an existing mark`
5. 新建 mark 时直接使用当前默认颜色与样式；点击 `Note` 时若选区尚未标注，则创建 mark 并同时写入首条 note；若已有单个 mark，则追加新 note。style bar 中可切换 `Highlight`（底色）或 `Underline`（下划线），并立即更新当前 mark。
6. `AnnotationStore.createMark()` / `createMarkWithNote()` / `createNote()` / `updateAnnotationAppearance()` 创建或更新 `AnnotationEntity` 与 notes 数据，并写入 `annotations` / `annotation_notes` 表。
7. Reader 同步更新当前书的 `ReaderPreferences.defaultMarkColor / defaultMarkStyle`，作为下次创建 mark 的默认值。
8. Reader 监听 annotation 变化，调用 `ReaderAnnotationResolver` 对当前章节执行：
   - exact restore
   - same-block fallback
   - same-chapter fallback
9. 成功恢复的 segment 被投影到当前 `PageLayout`：`Highlight` 以底色 overlay 绘制，`Underline` 在文本上方绘制下划线。
10. 用户点击 controls 中的 marks icon 时，Reader 打开侧边列表；点击某条 mark 后以 preview jump 方式跳转，并显示 `Back to previous location`。

## 关键状态与数据
- `AnnotationEntity.id / bookId / kind / style / quoteText / anchorJson / color / note / createdAt / updatedAt`
- `AnnotationNoteEntity.id / annotationId / bookId / text / createdAt`
- `AnnotationKind.mark`
- `AnnotationStyle.highlight / AnnotationStyle.underline`
- `AnnotationAnchorV1`
  - `version`
  - `parserVersion`
  - `segments[]`
  - `jumpTarget`
- `annotations` 表
  - `id`
  - `book_id`
  - `kind`
  - `style`
  - `quote_text`
  - `anchor_json`
  - `color`
  - `note`（latest note cache）
  - `created_at`
  - `updated_at`
- `annotation_notes` 表
  - `id`
  - `annotation_id`
  - `book_id`
  - `text`
  - `created_at`
- `AnnotationStore.state.items / isLoading / selectedColor / selectedStyle / notesByAnnotationId`
- `ReaderPreferences.defaultMarkColor / defaultMarkStyle`
- Rust parser block node `blockIndex`

## 交互与异常
- 无有效选区时不得创建 mark。
- 点击 `Mark` 时立即保存；上方紧凑样式栏只负责修改当前 mark 的颜色与样式，不再需要单独确认。
- 点击 `Note` 时打开底部 composer；空文本不得发布。
- 不允许创建与已有 mark 完全重复或重叠的 mark。
- 用户直接点击正文里已有的 mark 时，弹出已展开的 mark editor tooltip，可修改颜色/样式、追加新 note，或点击 `Unmark` 删除当前 mark。
- 当一次选区命中多个已有 marks 时，只允许 `Unmark`，不支持批量修改颜色/样式或批量加 note。
- 已保存 mark 在重新打开 Reader、修改字号、边距、行距后仍应尽量恢复。
- 从 marks 列表点进正文时，首次 preview jump 不应立即覆盖持久化阅读进度；只有用户继续翻页/继续阅读后，才把新位置视为当前进度。
- block 精确恢复失败时，允许退化到 same-block / same-chapter 文本匹配。
- 无法恢复时保留 annotation 记录，但不在正文中绘制 overlay。
- 旧 `highlights` 表在 DB v17 升级时被破坏式替换，不做 Locator 数据迁移。

## 验收标准
- Tooltip 中存在 `Mark` / `Edit` / `Note` / `Unmark` 动作。
- 用户点击 `Mark` 后会立即看到持久化标记；点击 `Note` 可以创建或追加 note；在样式栏切换颜色或样式时，当前页会立即更新。
- 重复或重叠 mark 会被拦截且不会产生重复数据。
- 重启应用后 annotation 仍可读取并重新渲染。
- controls 中可打开 marks 列表，点击列表项可以跳转并可返回原位置。
- 调整 ReaderPreferences 后 annotation 仍可正确恢复。
- `flutter analyze` 通过。
- `flutter test` 通过。

## 非目标
- 不实现 annotation 列表 / 编辑页。
- 不实现 note 富文本编辑。
- 不实现云端同步。
- 不保留旧 Readium `locatorJson` 的兼容渲染。
