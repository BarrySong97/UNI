# 模块：library

## 模块目的
承载首页书架浏览体验，提供分类浏览、书籍入口、导入入口和基础首页交互。

## 边界
### In
- 书籍列表加载与展示
- 分类标签切换与前端过滤
- 进入阅读页（按 bookId 路由）
- 触发导入流程入口
- 书架封面渲染（优先真实封面，缺失时占位；真实封面无灰边优先）

### Out
- 阅读器正文渲染与分页
- 划线创建与删除
- 书籍格式解析细节

## 核心流程
1. 页面初始化时触发 `LibraryStore.loadShelf()`。
2. store 从数据库读取书籍并生成 `filteredBooks`。
3. 用户点击分类标签触发 `setCategory()` 更新过滤结果。
4. 用户点击书籍进入 `reader` 模块。
5. 用户点击导入入口进入 `import` 模块流程。

## 关键状态与数据
- `LibraryState.books`
- `LibraryState.filteredBooks`
- `LibraryState.categories`
- `LibraryState.activeCategory`
- `LibraryState.isLoading / isImporting`
- `BookEntity.coverUrl`（data url 封面）

## 交互与异常
- 加载态：显示 loading。
- 空态：无书籍时展示空状态文案（`emptyLibrary`）。
- 导入失败：通过消息提示错误。
- 封面异常：真实封面解码失败时回退到占位封面。
- 真实封面显示策略：`BoxFit.cover`，优先填满封面区域（允许轻微裁切）。
- 导入中：页面显示遮罩 loading，避免用户误操作。
- 交互要求：标题、分类、书籍卡片布局在小屏下不出现 overflow。

## 验收标准
- 首页结构稳定渲染（top/title/tabs/grid）。
- 分类切换后列表即时更新。
- 点击书籍可进入阅读页。
- 导入 EPUB 后书架可显示真实封面；其他格式显示占位封面。
- 书架卡片仅显示 `book.title`（使用小号灰字样式），不显示作者行。
- 书架网格固定 3 列，列间距增大（`crossAxisSpacing=20`，`mainAxisSpacing=14`）。
- 重启应用后导入书籍仍可见（Android/iOS/macOS）。
- `flutter analyze` / `flutter test` 通过。

## 非目标
- 不负责推荐算法与书城排序。
- 不负责账号和云同步。
