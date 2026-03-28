# 模块：onboarding

## 模块目的
- 在首次启动时引导用户完成 AI 配置与离线语音能力初始化。
- 通过最短路径让用户可直接开始使用主流程（可继续或跳过）。

## 边界（In / Out）
### In
- 首次启动展示 `OnboardingFlow`。
- AI 配置页（Base URL / API Key）输入与保存。
- 语音模型下载页（US/UK）状态展示、下载与重试。
- 完成或跳过后写入完成标记并进入主壳页面。

### Out
- 主业务壳内的 Tab 导航与业务页面逻辑。
- 语音模型底层下载/解压实现细节（由 TTS 服务层负责）。
- AI 请求与解释结果展示逻辑。

## 核心流程
1. App 启动时根据 `onboarding_completed` 判断是否进入引导。
2. 第 1 步收集 AI 配置，可继续或跳过进入第 2 步。
3. 第 2 步展示离线语音模型状态，用户可下载后继续，或直接跳过。
4. 完成后写入完成标记，切换到主页面容器。

## 关键状态与数据
- `OnboardingFlow._currentPage`：当前页索引。
- `SharedPreferences['onboarding_completed']`：是否完成引导。
- `TtsModelManager` 的模型状态：`notDownloaded/downloading/extracting/ready/error`。
- 语音选择写入：`setVoiceForLanguage(languageCode, voiceKey)`。

## 交互与异常
- `OnboardingVoiceStep` 通过构造参数接收 `modelManager` 与 `onVoiceSelected`，避免在生命周期早期读取 inherited context。
- 语音下载失败时显示 `Failed` 并允许 `Retry`。
- 下载完成后自动写入对应语言默认 voice。
- 任一步都可 `Skip`，保证不阻断进入主流程。

## 验收标准
- 引导流程可按顺序完成并正确落盘完成标记。
- 语音页在无 `AppProvidersScope` 依赖注入场景下可安全构建。
- 点击 `Download` 后状态可更新为 `ready` 并触发 voice 保存回调。
- `flutter analyze` 与 `flutter test` 通过。

## 非目标
- 不在引导阶段提供完整语音列表筛选与试听能力。
- 不在引导阶段处理复杂 AI 配置校验或连通性检测。
