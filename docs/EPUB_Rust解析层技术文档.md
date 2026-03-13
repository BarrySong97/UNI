# EPUB Rust 解析层技术文档

> Flutter EPUB 阅读器 · Rust 解析模块 · v1.0

---

## 1. 概述

Rust 解析层是整个 EPUB 阅读器的核心基础，负责将 EPUB 文件解析为结构化数据，供 Flutter Canvas 层渲染使用。

**核心设计原则：**

- 只管内容和结构，不管渲染和坐标
- 输出与渲染参数（字体大小、屏幕尺寸）完全无关的稳定数据结构
- 单一解析器策略：全部使用 `html5ever`，不混用 XML 解析器
- 容错优先：市面上大量 EPUB 格式不规范，解析器必须能处理各种畸形输入

### 整体数据流

```
EPUB 文件 (.epub)
    ↓  rbook 解压 ZIP + 读取结构
    ↓  html5ever 解析 xhtml / opf / ncx
    ↓  过滤无用节点（script / style / meta 等）
    ↓  lightningcss 解析 CSS 样式
    ↓  生成 RenderNode 列表
    ↓  flutter_rust_bridge 传输到 Flutter 层
```

---

## 2. 依赖库清单

| 库名 | 版本 | 职责 | 选用理由 |
|------|------|------|----------|
| `rbook` | 0.6.10 | EPUB 结构解析 | 同时支持 EPUB2/3，支持 wasm32 编译 |
| `html5ever` | 0.27 | HTML/XHTML 解析 | 唯一通过全部容错测试的解析器 |
| `lightningcss` | 1.0 | CSS 解析 | 速度最快，支持完整 CSS3 |
| `zip` | 2.1 | ZIP 解压备用 | rbook 不覆盖的边缘场景 |
| `image` | 0.25 | 图片解码 | 支持 jpg/png/gif/webp 全格式 |
| `flutter_rust_bridge` | 2.0 | Flutter FFI 桥接 | 官方推荐，支持异步调用 |
| `unicode-segmentation` | 1.11 | Unicode 分词 | 选中功能的分词逻辑 |

### Cargo.toml

```toml
[dependencies]
rbook = "0.6.10"
html5ever = "0.27"
lightningcss = "1.0"
zip = "2.1"
image = "0.25"
flutter_rust_bridge = "2.0"
unicode-segmentation = "1.11"
```

---

## 3. 解析器选型：为什么全用 html5ever

EPUB 的所有内容文件（`.xhtml`、`.opf`、`.ncx`）虽然命名像 XML，但市面上大量书籍的内容并不严格遵循 XML 规范。使用严格的 XML 解析器会在遇到不规范内容时直接报错崩溃。

| 解析器 | 容错性 | 速度 | 处理不规范 HTML | 结论 |
|--------|--------|------|-----------------|------|
| `html5ever` | ✅ 最强 | ✅ 极快 | ✅ 完全支持 | ✅ 选用 |
| `quick-xml` | ❌ 严格 | ✅ 极快 | ❌ 直接报错 | ❌ 排除 |
| `xml-rs` | ❌ 严格 | ⚠️ 一般 | ❌ 直接报错 | ❌ 排除 |
| `scraper` | ✅ 好 | ✅ 快 | ✅ 支持 | ⚠️ 封装层过重 |

> `html5ever` 由 Mozilla Servo 项目开发，符合 WHATWG 规范，是唯一在全部容错测试中通过的解析器，同时具备 C 级别的性能表现。

---

## 4. EPUB 解析流程

### 4.1 解析入口顺序

每次打开一本 EPUB，Rust 层按以下固定顺序执行：

| 步骤 | 操作 | 使用工具 | 输出 |
|------|------|----------|------|
| 1 | 解压 ZIP 包 | rbook | 内存中的文件树 |
| 2 | 读取 mimetype | rbook | 验证格式合法性 |
| 3 | 读取 META-INF/container.xml | html5ever | OPF 文件路径 |
| 4 | 解析 content.opf | html5ever | metadata / manifest / spine |
| 5 | 解析目录（toc.ncx 或 nav.xhtml） | html5ever | 章节目录树 |
| 6 | 按 spine 顺序解析各章节 xhtml | html5ever | RenderNode 列表 |
| 7 | 解析关联 CSS 文件 | lightningcss | 样式规则表 |
| 8 | 按需解码图片 | image crate | 图片 bytes |

### 4.2 OPF 解析目标

`content.opf` 是 EPUB 的核心描述文件，解析后需提取三部分数据：

- **metadata**：书名、作者、语言、ISBN、出版日期、封面图 ID
- **manifest**：所有资源文件的 `id → 路径 → media-type` 映射表
- **spine**：章节阅读顺序（`itemref idref` 列表，对应 manifest 中的 id）

### 4.3 EPUB2 与 EPUB3 兼容策略

| 差异点 | EPUB2 | EPUB3 | 处理策略 |
|--------|-------|-------|----------|
| 目录文件 | toc.ncx | nav.xhtml | 两个都尝试解析，优先 nav.xhtml |
| 内容格式 | XHTML 1.1 | XHTML5 | html5ever 两者都支持 |
| CSS 支持 | CSS2 | CSS3 | lightningcss 完整支持 CSS3 |
| 媒体内容 | 有限 | 音频/视频 | 音视频节点直接过滤 |
| 数学公式 | 不支持 | MathML | MathML 节点降级为纯文本 |

---

## 5. HTML 节点过滤策略

阅读器只关心内容呈现，不关心页面行为。解析 xhtml 章节时必须对节点分类过滤。

### 5.1 过滤分类表

| 分类 | 节点列表 | 处理方式 |
|------|----------|----------|
| 直接丢弃 | `script` `style` `link` `meta` `head` `form` `input` `iframe` `noscript` | 解析时跳过，不生成任何 RenderNode |
| 核心保留 | `p` `h1~h6` `img` `em` `i` `strong` `b` `a` `br` `hr` `ol` `ul` `li` `figure` `figcaption` | 完整转换为对应 RenderNode |
| 扁平化处理 | `div` `span` `section` `article` `body` | 提取内部样式后标签本身扁平化，只保留子节点 |
| 结构化保留 | `table` `tr` `td` `th` `thead` `tbody` | 保留并自动结构化为表格 RenderNode |
| 降级处理 | `MathML` `SVG` `audio` `video` | MathML/SVG 转为占位文本，音视频直接忽略 |
| 条件保留 | `aside` `blockquote` `pre` `code` | 保留内容，标记特殊样式类型 |

### 5.2 过滤后的收益

| 指标 | 过滤前 | 过滤后 |
|------|--------|--------|
| HTML 节点数（典型章节） | ~500 个 | ~150 个 |
| CSS 规则数 | ~300 条 | ~30 条有效规则 |
| 传输数据量 | 完整 HTML | 减少约 60~70% |

### 5.3 Rust 过滤逻辑示例

```rust
pub fn should_discard(tag: &str) -> bool {
    matches!(tag,
        "script" | "style" | "link" | "meta" |
        "head" | "form" | "input" | "iframe" | "noscript"
    )
}

pub fn should_flatten(tag: &str) -> bool {
    matches!(tag, "div" | "span" | "section" | "article" | "body")
}

pub fn should_keep(tag: &str) -> bool {
    matches!(tag,
        "p" | "h1" | "h2" | "h3" | "h4" | "h5" | "h6" |
        "img" | "em" | "i" | "strong" | "b" | "a" |
        "br" | "hr" | "ol" | "ul" | "li" |
        "figure" | "figcaption" | "table" | "tr" | "td" | "th"
    )
}
```

---

## 6. RenderNode 数据结构

RenderNode 是 Rust 层输出给 Flutter 层的核心数据结构。它与渲染参数完全无关，只描述内容本身和逻辑样式。

### 6.1 核心定义

```rust
#[derive(Debug, Clone)]
pub enum RenderNode {
    Text {
        content: String,
        bold: bool,
        italic: bool,
        font_size_em: f32,         // 相对单位，不是像素
        color: Option<u32>,        // ARGB u32
        node_index: usize,         // 全书全局字符索引
    },
    Image {
        data: Vec<u8>,             // 图片二进制 bytes
        alt: Option<String>,
        width_hint: Option<f32>,   // 原始宽度比例 0.0~1.0
    },
    Paragraph {
        children: Vec<RenderNode>,
        margin_top_em: f32,
        margin_bottom_em: f32,
        align: TextAlign,
    },
    Heading {
        level: u8,                 // 1~6
        children: Vec<RenderNode>,
    },
    Table {
        rows: Vec<TableRow>,
    },
    LineBreak,
    HorizontalRule,
}

#[derive(Debug, Clone)]
pub enum TextAlign {
    Left,
    Center,
    Right,
    Justify,
}

#[derive(Debug, Clone)]
pub struct TableRow {
    pub cells: Vec<Vec<RenderNode>>,
    pub is_header: bool,
}
```

### 6.2 关键字段说明

| 字段 | 说明 |
|------|------|
| `font_size_em` | 使用相对单位 em，不使用像素。Flutter 层根据用户设置的字体大小动态换算 |
| `node_index` | 每个文本节点在全书中的全局字符索引，是选中功能和 CFI 定位的基础 |
| `image data` | 图片直接传 bytes，不传路径。Flutter 层用 MemoryImage 渲染 |
| `width_hint` | 原始图片宽度比例（0.0~1.0），供 Flutter 决定图片显示宽度 |
| `margin_top/bottom_em` | 使用 em 相对单位，Flutter 层根据实际字号换算为像素 |

---

## 7. CSS 处理策略

### 7.1 Rust 层提取的 CSS 属性

| CSS 属性 | 映射到 RenderNode 字段 | 备注 |
|----------|----------------------|------|
| `font-weight: bold` | `bold: true` | |
| `font-style: italic` | `italic: true` | |
| `font-size` | `font_size_em` | 统一换算为 em |
| `color` | `color: Option<u32>` | 转为 ARGB u32 |
| `text-align` | `align: TextAlign` | left/center/right/justify |
| `margin-top / margin-bottom` | `margin_top_em / margin_bottom_em` | 换算为 em |

### 7.2 直接忽略的 CSS 属性

- `position` / `float` / `z-index`：布局相关，Flutter 自己控制
- `animation` / `transition`：动画，阅读器不需要
- `background-image`：背景图，干扰阅读
- `font-family`：由用户在 Flutter 层自行选择字体
- `line-height`：由 Flutter 层统一设置，保证排版一致性

---

## 8. 图片处理策略

| 图片类型 | 处理方式 | 说明 |
|----------|----------|------|
| 封面图（cover） | 优先解码，随书籍元数据一起返回 | 从 OPF metadata 中的 cover id 定位 |
| 章节插图 | 懒加载，翻到该章节时解码 | 避免一次性解码全书图片 |
| 内联 base64 图片 | 直接解码 base64 data URI | 部分 EPUB 将图片内嵌为 base64 |
| SVG 图片 | 转为 PNG 或降级为占位符 | 复杂 SVG 直接忽略 |

---

## 9. 性能策略

### 9.1 按章节懒加载

- 打开书籍时：只解析 OPF + 目录结构 + 封面，速度极快
- 进入章节时：解析当前章节 xhtml + 关联 CSS
- 翻页时：提前解析下一章节（后台预加载）

### 9.2 图片内存管理

- 当前页 ±2 页的图片保留在内存
- 超出范围的图片释放，下次需要时重新解码
- 封面图常驻内存

### 9.3 预期性能基准

| 操作 | 目标耗时 | 说明 |
|------|----------|------|
| 打开书籍（解析 OPF + 目录） | < 50ms | 用户无感知 |
| 解析单个章节（纯文字） | < 30ms | 翻页流畅 |
| 解析单个章节（图文混排） | < 100ms | 可接受 |
| 解码单张插图（1MB 以内） | < 20ms | image crate 原生速度 |

---

## 10. Rust 层与 Flutter 层的边界

| 职责 | Rust 层 | Flutter 层 |
|------|---------|------------|
| ZIP 解压 | ✅ | |
| OPF / 目录解析 | ✅ | |
| HTML 节点过滤 | ✅ | |
| CSS 样式提取 | ✅ | |
| 图片解码 | ✅ | |
| Unicode 分词 | ✅ | |
| 生成 RenderNode | ✅ | |
| 像素坐标计算 | | ✅ |
| TextPainter 量尺寸 | | ✅ |
| Canvas 分页 | | ✅ |
| Canvas 绘制 | | ✅ |
| 手势识别 | | ✅ |
| 选中高亮绘制 | | ✅ |
| 字体大小设置 | | ✅ |
| 翻页动画 | | ✅ |

---

*本文档描述 Rust 解析层的设计决策与实现规范，Flutter 渲染层文档另行维护。*
