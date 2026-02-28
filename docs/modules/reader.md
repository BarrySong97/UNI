# 模块：reader

## 模块目的
提供章节阅读、进度恢复、进度保存、章节切换和阅读页基础设置入口。

## 边界
### In
- 打开书籍并恢复上次阅读位置
- 滚动更新阅读进度
- 节流保存 + 离开页面强制保存
- 阅读页内跳转到设置与划线列表

### Out
- 书籍导入与格式解析
- 划线数据存储实现细节
- 社区、推荐等业务

## 核心流程
1. 根据 `bookId` 打开书籍，读取章节与进度。
2. 定位到目标章节和字符偏移。
3. 滚动时更新偏移并节流保存。
4. 页面销毁或切章时强制 flush 进度并写入 SQLite。

## 关键状态与数据
- `ReaderState.book / chapter / chapters`
- `ReaderState.charOffset / percent`
- `ReaderState.isLoading / isSaving`
- `ReadingProgressEntity`
- `reading_progress` 表（`book_id` 主键）

## 交互与异常
- 选中文本后支持创建高亮。
- 点击空白区域取消选中。
- 保存失败应提示并不中断阅读。
- 无章节时不崩溃，回退到可用状态。

## 验收标准
- 可稳定恢复阅读进度。
- 滚动更新与保存行为正确。
- 无选区残留和系统菜单崩溃问题。
- 应用重启后可恢复上次阅读进度（Android/iOS/macOS）。
- `flutter analyze` / `flutter test` 通过。

## 非目标
- 不实现复杂仿真翻页动画。
- 不实现听书、语音朗读。
