# 模块：highlight

## 模块目的
提供阅读高亮（划线）创建、渲染、删除与列表查看能力，基于 Readium Locator（CFI）定位。

## 边界
### In
- 根据 Readium 选区创建高亮（获取 Locator + 选中文本）
- 按书籍读取高亮列表
- 删除高亮
- 通过 Readium Decoration API 渲染高亮

### Out
- 阅读器进度保存
- 导入解析逻辑
- 高亮云同步

## 核心流程
1. 用户在 Readium 阅读器中选中文本。
2. 获取当前选区的 Readium Locator（包含 CFI 位置）和选中文本。
3. 创建 `HighlightEntity`，存储 `locatorJson` 和 `selectedText`。
4. 写入 repository（SQLite）并刷新当前列表。
5. 通过 `flureadium.applyDecorations()` 将高亮渲染到 Readium 层。
6. 删除高亮后从数据库移除并更新 Readium decorations。

## 关键状态与数据
- `HighlightState.items / selectedColor / isLoading`
- `HighlightEntity.id / bookId / locatorJson / selectedText / color / note`
- `highlights` 表（`id` 主键，`book_id` 索引）
- `locatorJson` — Readium Locator JSON（包含 CFI 位置信息）

## 交互与异常
- 选中文本后通过菜单创建高亮。
- 无选区时不得创建。
- 删除后列表和阅读页要同步更新 decorations。
- 删除图书时，该图书关联的高亮需级联删除。
- Locator 解析失败时静默跳过该高亮的渲染。

## 验收标准
- 创建/删除链路可用。
- 高亮在 Readium 阅读器中正确渲染（通过 Decoration API）。
- 列表页可查看并删除。
- 应用重启后高亮数据仍可读取并正确渲染。
- `flutter analyze` 通过。

## 非目标
- 不实现多色主题管理面板。
- 不实现云端协作标注。
- 不兼容旧版 offset-based 高亮数据（破坏式重构）。
