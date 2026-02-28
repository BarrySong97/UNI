# 模块：shell-navigation

## 模块目的
提供应用级页面容器与底部 Tab 导航，保障多 Tab 页面状态保留。

## 边界
### In
- 底部导航切换
- 页面容器管理
- Tab 状态保留（IndexedStack）

### Out
- 模块内部业务逻辑（library/reader/highlight/import）
- 深链复杂分发

## 核心流程
1. App 入口进入 `MainTabShellPage`。
2. 使用 `IndexedStack` 承载 `Library/Discover/Read`。
3. 点击底部 Tab 更新 `currentIndex`。
4. 未激活页面状态继续保留。

## 关键状态与数据
- `MainTabShellPage.currentIndex`
- `IndexedStack.children`
- `BottomNavigationBar.currentIndex`

## 交互与异常
- 切换 Tab 不丢状态。
- 页面切换平滑，不重新初始化已激活页面。
- 导航组件与页面背景风格一致。

## 验收标准
- 三个 Tab 均可切换。
- 回切后状态保留。
- 路由入口指向 shell。
- `flutter analyze` / `flutter test` 通过。

## 非目标
- 不实现多层嵌套路由守卫。
- 不实现动态 Tab 配置下发。
