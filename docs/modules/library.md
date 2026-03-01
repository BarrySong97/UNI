# 模块：library

## 模块目的
承载首页书架浏览体验，提供分类浏览、书籍入口、导入入口和基础首页交互。

## 边界
### In
- 书籍列表加载与展示
- 分类标签切换与前端过滤
- 点书后根据规则进入 `Book Profile` 或阅读页
- 触发导入流程入口
- 书架封面渲染（优先真实封面，缺失时占位；真实封面无灰边优先）
- `Book Profile` 首屏背景渐变（优先使用导入存储色，缺失时再提取并回填）
- `Book Profile` 设置菜单删除书籍（级联删除章节/进度/划线）

### Out
- 阅读器正文渲染与分页
- 划线创建与删除
- 书籍格式解析细节

## 核心流程
1. 页面初始化时触发 `LibraryStore.loadShelf()`。
2. store 从数据库读取书籍并生成 `filteredBooks`。
3. 用户点击分类标签触发 `setCategory()` 更新过滤结果。
4. 用户点击书籍后由 `BookProfileEntryService` 判定入口：
   - 无阅读进度：进入 `Book Profile`（`/book-detail`）。
   - 有阅读进度：直接进入 `reader`。
5. 用户点击导入入口进入 `import` 模块流程。

## 关键状态与数据
- `LibraryState.books`
- `LibraryState.filteredBooks`
- `LibraryState.categories`
- `LibraryState.activeCategory`
- `LibraryState.isLoading / isImporting`
- `BookEntity.coverUrl`（data url 封面）
- `BookEntity.profileBgColor`（`#AARRGGBB`）
- `BookProfileEntryService.resolveEntry(bookId)`
- `BookProfileColorService.gradientFromStoredHex(...)`

## 交互与异常
- 加载态：显示 loading。
- 空态：无书籍时展示空状态文案（`emptyLibrary`）。
- 导入失败：通过消息提示错误。
- 封面异常：真实封面解码失败时回退到占位封面。
- 真实封面显示策略：`BoxFit.cover`，优先填满封面区域（允许轻微裁切）。
- `Book Profile` 顶部背景优先使用 `profileBgColor` 生成渐变；无存储色时实时取色并回填，失败回退默认渐变。
- `Book Profile` 状态栏区域延续顶部渐变（封面取色/存储色），保持与上半区视觉连续。
- `Book Profile` 设置菜单可删除图书，删除确认后级联清理该书关联数据，并统一返回书架入口。
- `Book Profile` 顶栏显示当前书名（超长省略）；作者为 `Unknown` 时不展示作者行。
- `Book Profile` 下半区展示当前书的 `My Highlights`（点击可进入 highlights 列表）。
- 阅读进度独立放置在封面区块下方一行（`Page + Percent`），`Continue` 使用主按钮样式。
- `View All` 使用轻量描边按钮样式，与 highlights 区域视觉一致。
- 导入中：页面显示遮罩 loading，避免用户误操作。
- 交互要求：标题、分类、书籍卡片布局在小屏下不出现 overflow。

## 验收标准
- 首页结构稳定渲染（top/title/tabs/grid）。
- 分类切换后列表即时更新。
- 点击书籍可按首次规则进入 `Book Profile` 或阅读页。
- 导入 EPUB 后书架可显示真实封面；其他格式显示占位封面。
- `Book Profile` 字体大小与颜色通过 `LibraryDesignTokens` 管理，避免页面内大号硬编码。
- 书架卡片仅显示 `book.title`（使用小号灰字样式），不显示作者行。
- 书架网格固定 3 列，列间距增大（`crossAxisSpacing=20`，`mainAxisSpacing=14`）。
- 重启应用后导入书籍仍可见（Android/iOS/macOS）。
- 每本书首次点击（无 `reading_progress`）进入 `Book Profile`，后续点击直进阅读页。
- 删除图书后，该图书及关联章节/进度/划线不再可见。
- `flutter analyze` / `flutter test` 通过。

## 非目标
- 不负责推荐算法与书城排序。
- 不负责账号和云同步。
