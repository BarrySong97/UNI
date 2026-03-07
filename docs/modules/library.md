# 模块：library

## 模块目的
承载首页阅读仪表板体验，提供阅读统计概览、当前在读书籍快捷入口、书架网格浏览、导入入口和基础首页交互。

## 边界
### In
- 首页仪表板布局（Header / Stats / Now Reading / Word of the Day / Book Grid）
- 书籍列表加载与展示
- "Now Reading" 当前在读书籍卡片（基于最近阅读进度 updatedAt）
- 书架 2 列网格（最多 8 本，按最近阅读时间排序）
- 点书后根据规则进入 `Book Profile` 或阅读页
- 触发导入流程入口（Header "+" 按钮）
- 空状态处理（无书时隐藏统计和功能区，显示 "Add Your First Book" 按钮）
- 书架封面渲染（优先真实封面，缺失时占位；真实封面无灰边优先；封面卡片使用双层圆角容器设计，外层为浅色调背景）
- `Book Profile` 首屏背景渐变（优先使用导入存储色，缺失时再提取并回填）
- `Book Profile` 设置菜单删除书籍（级联删除章节/进度/划线）

### Out
- 阅读器正文渲染与分页
- 划线创建与删除
- 书籍格式解析细节
- 用户档案与头像管理

## 核心流程
1. 页面初始化时触发 `LibraryStore.loadShelf()`。
2. store 从数据库读取书籍，加载阅读进度（percent + updatedAt）。
3. `LibraryPage` 计算派生数据：
   - `nowReadingBook`：`progressUpdatedMap` 中 updatedAt 最新的书。
   - `gridBooks`：排除 nowReadingBook 后，按 updatedAt 降序排列，取前 8 本。
4. 用户点击 "Continue" 按钮直接进入阅读器。
5. 用户点击网格中的书籍由 `BookProfileEntryService` 判定入口：
   - 无阅读进度：进入 `Book Profile`（`/book-detail`）。
   - 有阅读进度：直接进入 `reader`。
6. 用户点击 "+" 导入按钮进入 `import` 模块流程。

## 首页布局结构
```
LibraryHeader ("MY LIBRARY" + "Reading" 标题 + "+" 导入按钮 + 用户头像)
LibraryReadingStats (DAILY GOAL 卡片 + BOOKS READ 卡片)
Now Reading 区域 (Section Header + NowReadingCard)
WordOfDayCard (静态占位)
LibraryBookGrid (2 列网格，最多 8 本)
```

空状态时仅显示 Header + "Add Your First Book" 按钮。

## 关键状态与数据
- `LibraryState.books`
- `LibraryState.filteredBooks`
- `LibraryState.progressMap`（Map<String, double>）
- `LibraryState.progressUpdatedMap`（Map<String, DateTime>）
- `LibraryState.isLoading / isImporting`
- `BookEntity.coverUrl`（data url 封面）
- `BookEntity.profileBgColor`（`#AARRGGBB`）
- `BookProfileEntryService.resolveEntry(bookId)`

## 交互与异常
- 加载态：显示 loading。
- 空态：无书籍时展示 "Add Your First Book" 按钮，隐藏统计和功能模块。
- 导入失败：通过消息提示错误。
- 封面异常：真实封面解码失败时回退到占位封面。
- Now Reading 卡片：无阅读进度时不显示该区域。
- 真实封面显示策略：`BoxFit.cover`，优先填满封面区域（允许轻微裁切）。
- `Book Profile` 顶部背景优先使用 `profileBgColor` 生成渐变。
- `Book Profile` 设置菜单可删除图书，删除确认后级联清理该书关联数据。
- `Book Profile` 布局：居中封面 → 书名 → 作者 → 三个统计项 → Continue Reading 按钮。
- `Book Profile` 作者为 `Unknown` 时不展示作者行。
- 导入中：页面显示遮罩 loading，避免用户误操作。

## 验收标准
- 首页结构稳定渲染（Header / Stats / Now Reading / Word of the Day / Grid）。
- Now Reading 显示最近阅读的书（基于 progressUpdatedMap 最新 updatedAt）。
- 网格为 2 列布局，每个 tile 下方显示书名和作者。
- 网格最多显示 8 本，按最近阅读时间排序。
- 空状态显示 "Add Your First Book" 按钮。
- 点击 "Continue" 按钮直接进入阅读器。
- 导入 EPUB 后书架可显示真实封面；其他格式显示占位封面。
- 重启应用后导入书籍仍可见。
- 删除图书后，该图书及关联数据不再可见。
- `flutter analyze` / `flutter test` 通过。

## 非目标
- 不负责推荐算法与书城排序。
- 不负责账号和云同步。
- Word of the Day 为静态占位，不接入真实词频数据。
- 阅读时长统计为 mock 数据，不接入真实时长追踪。
