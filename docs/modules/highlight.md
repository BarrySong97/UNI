# 模块：highlight

## 模块目的
提供阅读高亮（划线）创建、渲染、删除与列表查看能力。

## 边界
### In
- 根据选区创建高亮
- 按章节/书籍读取高亮
- 删除高亮
- 对重叠高亮排序渲染

### Out
- 阅读器进度保存
- 导入解析逻辑
- 高亮云同步

## 核心流程
1. 读取当前选区 start/end。
2. 生成锚点信息（selectedText/prefix/suffix）。
3. 写入 repository（SQLite）并刷新当前列表。
4. 渲染时按规则排序并应用样式。
5. 删除高亮后即时重绘。

## 关键状态与数据
- `HighlightState.items / selectedColor / isLoading`
- `HighlightEntity.startOffset/endOffset`
- `HighlightEntity.selectedText/prefixContext/suffixContext`
- `HighlightResolverService`
- `highlights` 表 + `(book_id, chapter_id, start_offset)` 索引

## 交互与异常
- 菜单入口 + FAB 双入口创建高亮。
- 无选区时不得创建。
- 删除后列表和阅读页要同步。
- 偏移失效时尝试用上下文重定位。

## 验收标准
- 创建/删除链路可用。
- 重叠高亮渲染稳定。
- 列表页可查看并删除。
- 应用重启后高亮数据仍可读取（Android/iOS/macOS）。
- `flutter analyze` / `flutter test` 通过。

## 非目标
- 不实现多色主题管理面板。
- 不实现云端协作标注。
