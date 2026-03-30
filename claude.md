# AGENTS.md

本文件定义本仓库中 AI Agent 与开发者协作时的默认约定。

## 语言要求
- **所有回答必须使用中文**。

## 项目类型
- Flutter 应用（多端：`android`/`ios`/`web`/`macos`/`linux`/`windows`）。
- 核心业务代码在 `lib/`，测试在 `test/`。

## 工作范围
- 优先修改与需求直接相关的最小文件集合。
- 不主动重构无关模块，不修改生成产物和平台脚手架，除非需求明确要求。
- 避免提交临时调试代码、注释掉的大段旧逻辑或无关格式化变更。

## 常用命令
- 安装依赖：`flutter pub get`
- 运行应用：`flutter run`
- 静态检查：`flutter analyze`
- 运行测试：`flutter test`
- 构建 Web：`flutter build web`

## 代码规范
- 遵循 `analysis_options.yaml` 中的 lint 规则。
- 新增代码保持小函数、清晰命名、必要时加简短注释（解释"为什么"而非"做了什么"）。
- 公共 API 或关键行为变更需同步更新测试。
- **UI 文本优先使用英文**：所有界面文字、标签、提示等优先使用英文。

## 模块业务文档访问规则
- 模块业务说明不内嵌在 `AGENTS.md`，统一放在 `docs/modules/*.md`。
- 模块文档路径规则：`docs/modules/<module>.md`。
- 首批模块映射：
  - `library` -> `docs/modules/library.md`
  - `reader` -> `docs/modules/reader.md`
  - `highlight` -> `docs/modules/highlight.md`
  - `import` -> `docs/modules/import.md`
  - `shell/navigation` -> `docs/modules/shell-navigation.md`
- 在开发前，Agent 必须先读取对应模块文档；跨模块改动必须读取所有相关模块文档。
- 若模块文档缺失：先按统一模板新建文档，再进行实现。
- 功能变更后，必须同步更新对应模块文档，并在任务输出中明确说明“已更新模块文档”。
- 模块文档使用统一结构：
  - 模块目的
  - 边界（In / Out）
  - 核心流程
  - 关键状态与数据
  - 交互与异常
  - 验收标准
  - 非目标

## 测试要求
- 变更业务逻辑时，至少补充/更新对应单元测试或组件测试。
- 提交前至少执行：
  - `flutter analyze`
  - `flutter test`

## 提交与说明
- 每次任务输出需说明：
  - 修改了哪些文件
  - 为什么这样改
  - 如何验证（命令与结果）
- 若存在无法在本地验证的部分，需明确标注风险与后续建议。

## 禁止事项
- 未经明确要求，不执行破坏性命令（如删除大量文件、重置历史）。
- 未经确认，不引入大型依赖或升级 SDK 版本。

## gstack

Use the `/browse` skill from gstack for all web browsing. Never use `mcp__claude-in-chrome__*` tools.

Available gstack skills:
- `/office-hours` — structured office hours / Q&A session
- `/plan-ceo-review` — CEO-level plan review
- `/plan-eng-review` — engineering plan review
- `/plan-design-review` — design plan review
- `/design-consultation` — design consultation
- `/review` — code review
- `/ship` — ship a feature end-to-end
- `/land-and-deploy` — land and deploy changes
- `/canary` — canary deploy
- `/benchmark` — performance benchmarking
- `/browse` — fast headless browser for web browsing, QA, and site dogfooding
- `/qa` — full QA pass
- `/qa-only` — QA without shipping
- `/design-review` — design review
- `/setup-browser-cookies` — set up browser cookies
- `/setup-deploy` — set up deployment configuration
- `/retro` — retrospective
- `/investigate` — investigate an issue
- `/document-release` — document a release
- `/codex` — OpenAI Codex integration
- `/cso` — chief security officer review
- `/careful` — careful/cautious mode
- `/freeze` — freeze a branch
- `/guard` — guard a branch
- `/unfreeze` — unfreeze a branch
- `/gstack-upgrade` — upgrade gstack

If gstack skills aren't working, run `cd .claude/skills/gstack && ./setup` to build the binary and register skills.
