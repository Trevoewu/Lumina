# Lumina UI Design System

本文档定义 Lumina 当前采用的 UI 语言、代码约束和验收标准。它是实现规范，不是概念稿。若文档与代码不一致，以 `AppDesignTokens`、`AppTextStyles` 和 `AppTheme` 为当前事实，并在同一变更中修正文档。

## 1. 设计方向

Lumina 的设计方向是 **Editorial Listening**：操作界面现代、克制，阅读内容保留适量书卷感。

核心原则：

1. **界面与内容分工明确**：导航、搜索、按钮和元数据使用系统无衬线字体；词头、原文和歌词可以使用用户选择的阅读字体。
2. **标准页面统一，播放器允许沉浸**：Home、Dictionary、Me 使用同一套页面语法；Player 是同一系统的 immersive variant，不是第四套设计。
3. **主要靠排版与留白建立层级**：卡片只用于表达真实的表面层级，不用灰色圆角矩形包裹所有内容。
4. **语义优先于数值**：页面读取 token 和组件主题，不在业务代码中重新定义字号、圆角、边距或颜色。
5. **品牌色保持稳定**：封面色负责氛围，不能临时取代全局 `primary`。

## 2. 代码权威与依赖方向

设计系统的依赖方向必须保持单向：

```text
AppColors / AppTextStyles / AppDesignTokens
                    ↓
                AppTheme
                    ↓
     Material component themes + shared widgets
                    ↓
                 Screens
```

权威文件：

- `lib/core/app_colors.dart`：暗色、亮色和语义颜色映射。
- `lib/core/app_text_styles.dart`：UI 排版角色。
- `lib/core/app_design_tokens.dart`：间距、圆角、控件尺寸和阅读字体。
- `lib/core/theme.dart`：将上述规则注入 `ThemeData`。
- `lib/presentation/widgets/design_system/`：业务页面可直接使用的共享组件。

约束：

- `ThemeData.cardTheme`、`InputDecorationTheme` 等 Material 主题和自定义组件必须读取同一份 token。
- 不允许创建与 Theme 平行的第二套常量体系。
- 如果一个新数值会在两个以上页面使用，应先进入 token 或语义组件，再进入页面。

## 3. 字体系统

### 3.1 UI 字体

UI 默认使用平台系统字体，即 Theme 不设置应用级 `fontFamily`：

- Apple 平台使用系统提供的 SF 系列。
- Android 使用系统提供的 Roboto。
- 不打包 Inter，不为视觉完全一致付出字体体积和 fallback 维护成本。

以下内容必须使用 UI 字体：

- 页面标题和工具栏
- Tab、按钮、搜索框
- Section header
- 列表标题、标签、时间、来源等元数据

### 3.2 阅读字体

`AppDesignTokens.readingFontFamily` 是独立的阅读字体设置。使用：

```dart
Text(
  sentence,
  style: context.readingStyle(Theme.of(context).textTheme.bodyLarge!),
)
```

阅读字体只应用于：

- 词典 headword
- 书中原文例句
- 歌词、字幕和长篇阅读正文

不要将阅读字体应用到导航、控件或元数据。用户选择 Serif 或 Mono 时，UI chrome 仍保持系统字体。

### 3.3 排版角色

| Theme role | 规格 | 用途 |
| --- | --- | --- |
| `headlineLarge` | 34 / 1.12 / 700 | Tab 根页面 Large Title |
| `headlineMedium` | 22 / 1.25 / 700 | 页面级重要标题 |
| `headlineSmall` | 18 / 1.2 / 700 | 折叠后的 inline 页面标题 |
| `titleLarge` | 22 / 1.25 / 700 | 内容标题、播放器章节标题 |
| `titleMedium` | 16 / 1.3 / 700 | Section 和列表主标题 |
| `bodyLarge` | 16 / 1.5 / 400 | 释义、正文、主要说明 |
| `bodyMedium` | 14 / 1.4 / 400 | 次级说明 |
| `labelLarge` | 14 / 1.3 / 600 | 按钮、紧凑标签 |
| `bodySmall` | 12 / 1.35 / 500 | 来源、时间和 caption |

Large Title 展开和折叠过程只改变字号、位置和对齐，不改变字重。展开为 `34/700`，折叠为 `18/700`，禁止使用 `800` 或在动画中切换 weight。

页面不得直接写 `fontSize` 和 `fontWeight` 来创造已有角色。确有新角色时，先更新 `AppTextStyles` 并说明用途。

### 3.4 字重纪律与非加粗原则 (Strict Font Weight Discipline)

- **唯一加粗例外**：全局仅允许两处使用加粗效果：
  1. 页面最大标题（`headlineLarge`，如 Tab 根页面的主要大标题 Large Title）；
  2. 顶部固定控制栏选中的切换项字体（`PageControlTabs` 选中项）。
- **严格非加粗约束**：除上述两处外，**其余所有界面元素一律严禁使用加粗字体（不得使用 `FontWeight.bold` / `w700` / `w800`）**。包括但不限于书籍标题、Podcast 标题、章节标题、副标题、标签、说明文字、元数据以及长文正文，统一使用常规字重（`FontWeight.normal` / `400` 或 `500`）。

## 4. 间距与布局

### 顶部固定控制栏

- macOS 主显示区顶部与窗口按钮栏共用 36 pt 高度，使用 `MacosPageToolbar`，上方不再添加留白。侧边栏收起或缩窄时，由 `MacosPageToolbarScope` 统一预留窗口按钮的横向空间。
- 页面级视图切换统一使用 `PageControlTabs<T>`，Home 和 Discover 共用同一实现；新页面不得另写胶囊或填色 Chip 作为顶部视图切换。
- 样式以 Home 为标准：16 pt 系统字体，选中为主文字色、800 字重，未选中为主文字色 35% 透明度、600 字重；选中项下方显示 2 pt 圆角下划线，与文字间隔 7 pt，项目间距 22 pt。这是顶部切换控件的专用排版角色。
- 切换项左对齐，左边距为页面 inset + 6 pt；窄窗口可横向滚动。文字状态过渡 250 ms，下划线缩放过渡 300 ms。组件提供选中状态语义。
- 顶部栏固定，标题和列表等放入下方内容区。页面搜索使用 `PageToolbarSearch` 放在切换项右侧：空间充足时显示 28 pt 高的长条圆角搜索框，输入框可用宽度不足 200 pt 时仅显示放大镜；点击后在同一顶部栏展开输入，关闭后恢复切换项，保留查询内容。新增操作放在控制栏尾部。移动端复用切换样式，自然高度为 44 pt，保留平台安全区。


间距 scale：

| Token | 值 |
| --- | ---: |
| `spaceXs` | 4 |
| `spaceSm` | 8 |
| `spaceMd` | 12 |
| `spaceLg` | 16 |
| `spaceXl` | 24 |
| `spaceXxl` | 32 |

页面水平边距：

- 常规宽度：`pageGutter = 24`
- 宽度不超过 360：`compactPageGutter = 16`
- 必须通过 `context.appDesign.pageInsetFor(width)` 获取。
- `20` 不是布局 token，不得作为页面边距或卡片 padding 新增。

示例：

```dart
final design = context.appDesign;
final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);

ListView(
  padding: EdgeInsets.fromLTRB(inset, design.spaceLg, inset, 120),
)
```

嵌套内容可以使用 `spaceLg`，但必须明确它是组件内边距，而不是新的页面 gutter。

## 5. 圆角、尺寸与表面

### 5.1 圆角系统 (Border Radius)

Lumina 建立严格的四层语义圆角尺度，禁止在业务代码中随意使用 `10`、`14`、`18`、`20` 等非标魔数：

| Token | 值 | 语义层级 | 典型使用场景 |
| --- | ---: | --- | --- |
| `radiusSmall` | 8 | 紧凑元素、媒体微缩图 | 书封封面（Book Cover）、MiniPlayer 封面缩略图、小型多媒体元素、次级状态标签（Badge / Chip） |
| `radiusMedium` | 12 | 基础容器、输入框、卡片 | 搜索框（`AppSearchField`）、标准列表项、通用卡片（`AppSurface.standard`）、例句块、选择器弹层容器 |
| `radiusLarge` | 16 | 模态视窗、浮层、沉浸面板 | 歌词面板（Lyrics）、Bottom Sheet 顶部圆角、沉浸式卡片面板、对话详情容器 |
| `radiusPill` | 999 | 强调胶囊、主动作按键 | 全局 CTA 操作按钮、胶囊筛选器、分段指示器胶囊、圆角开关滑块 |

规则约束：
- 严格遵循语义层级，不新增平行数值。如需视觉特例，必须证明其代表一种新的系统级容器层级。
- 组合控件（如输入框内嵌按钮、卡片嵌套子元素）遵循内部圆角比外部圆角小一级的视觉嵌套韵律（Nested Radius Principle）。

### 5.2 控件尺寸

- 最小触控区域：`44 × 44`
- 标准搜索/输入控件高度：`52`
- 标准页面 toolbar 高度：`56`
- 图标视觉尺寸通常为 `20–24`，触控区域仍不得低于 44。

### 5.3 表面层级

使用 `AppSurface`：

| Level | 语义 | 默认实现 |
| --- | --- | --- |
| `standard` | 普通列表项、分组 | `surfaceContainer`、radius 12、无 elevation |
| `elevated` | 需要从当前内容中抬起的上下文 | `surfaceContainerHighest`、radius 12、低 elevation |
| `immersive` | 播放和沉浸内容面板 | `surfaceContainerHigh`、radius 16 |

规则：

- 不要在同一内容层连续嵌套多个 `AppSurface`。
- 不要把整篇详情页放进一张巨型卡。
- 例句、播放上下文、可交互列表可以使用表面；连续释义正文优先使用页面背景和留白。
- `AppSurface` 与 `CardTheme` 读取同一 token。不要在页面中重新模拟 Card。

### 5.4 卡片操作交互

带上下文操作的内容卡片统一使用 `AnimatedPressableCard`：

- 单击执行卡片的主要动作，例如打开书籍、章节或单集。
- 长按打开 `showHalfScreenActionSheet` 操作菜单。
- 长按反馈由共享组件统一提供：轻微缩放动画和中等强度振动。
- 不在卡片尾部放置“…”按钮；尾部仅用于完成状态、下载进度等非操作状态。
- 新卡片需要上下文操作时，应传入 `onLongPress`，不得在业务页面重新实现手势、动画或振动。

页面工具栏的更多菜单不属于卡片交互，可以继续使用明确的菜单按钮。

### 5.5 分割线与边界贯通 (Dividers & Full-Height Boundary Spanning)

分割线用于定义应用架构边界与分组结构，统一规格与交互规范：

1. **厚度与颜色规范**：
   - 分割线宽度/厚度严格固定为 `1px`（逻辑像素 `1.0`，即 `tokens.dividerThickness`）。
   - 标准中性分割线颜色统一采用 `#E3E3E1`（`AppColors.divider` / `Color(0xFFE3E3E1)`）。
   - 全局 `ThemeData.dividerTheme` 默认注入该配置：`thickness: 1.0, space: 1.0, color: AppColors.divider`。

2. **全高边界贯通（Full-Height Boundary Spanning）**：
   - 桌面端结构分割线（如侧边栏与主工作区之间的竖向分割线/分栏拖拽手柄）必须**全高贯通**，从应用物理窗口的最顶部边缘（`y = 0`，与原生红绿灯控件所在水平线对齐）一直延展到物理窗口的最底部边缘，不得被外层 padding、SafeArea 或 Toolbar 截断。
   - 侧边栏内部元素间（如底部 Me 个人资料卡片与上方导航 Rail）的横向分割线同样使用 `height: 1, thickness: 1, color: AppColors.divider` 紧贴侧边栏两侧边缘贯穿。

3. **拖拽手柄热区与视觉呈现解耦**：
   - 可拖拽分割线（如桌面侧边栏宽度调节 Splitter）承载交互时，交互热区必须足够宽（如外层 `width: 8.0` 并设置 `SystemMouseCursors.resizeColumn`），内部居中绘制 `1.0px` 细线。
   - 保证鼠标与触控点击易用性的同时，视觉上保持极致克制、精致的 1px 分割线质感。

### 5.6 图标系统：HugeIcons Stroke / Rounded 风格

App 全局图标统一采用 **HugeIcons Stroke / Rounded** 视觉家族：

- 页面使用 `AppIcon(AppIcons.search01)` 等共享语义图标，参数类型为 `AppIconData`，不再使用 Material `Icons` / `IconData` 或 SF Symbols。大小、颜色和禁用透明度由 `IconTheme` 继承。
- 原生底部导航和返回按钮使用 `assets/ui_icons/` 中从同一 HugeIcons 矢量数据生成的透明图标，保留原生交互。更新方式：`flutter test tool/generate_native_icons_test.dart`，同时生成 1x/2x/3x 资源。
- 更多菜单按钮使用 `AppGlassSurface` 加 `AppIcon(AppIcons.moreHorizontal)` 直接渲染，避免原生图片加载导致图标空白。播放器主播放／暂停按钮使用透明背景，图标随主题取前景色，保留原有点击区域。
- 服务商品牌 Logo、应用图标、书籍封面不是界面操作图标，保留原始资源。系统 AirPlay 路由选择器的图标与活动状态由 iOS 管理，保留系统实现。


1. **风格与线型特征**：
   - 统一使用 Stroke（线性轮廓描边）搭配 Rounded（圆角/圆润端点），如 `HugeIcons.strokeRounded*` 系列。
   - 避免 Sharp、Solid（除非明确的实心选中态）或直角生硬的图标风格，保持界面细腻、现代、具亲和力的视觉气质。

2. **尺寸与触控区域分离**：
   - 图标视觉尺寸通常为 `20–24pt`（桌面端导航图标基准为 `24pt`，行内辅助图标为 `20pt`）。
   - **交互区域保证**：独立可点击图标的触控区域（Hit Target）严禁直接设为 24×24，必须遵循 `minimumTouchTarget`（`≥ 44×44pt`），通过外层 padding 或 `IconButton` 保证可触控性。

3. **语义色彩映射**：
   - 图标颜色严格随上下文继承环境主题，严禁硬编码颜色：
      - 主要图标：`Theme.of(context).colorScheme.onSurface`
      - 次级/未选中图标：`Theme.of(context).colorScheme.onSurfaceVariant`
      - 激活/选中/强调图标：`Theme.of(context).colorScheme.primary`
   - 桌面端导航项推荐使用共享组件 `AppNavigationIcon`（`lib/presentation/widgets/design_system/app_navigation_icon.dart`），通过 `AppNavigationSymbol` 统一定义与维护。

### 5.7 macOS 顶部常驻窗口控制栏规范与单一控制区原则 (Top Window Toolbar & Single Control Zone Principle)

在 macOS 桌面端，应用骨架统一采用 `AppScaffold` 顶部的一体化常驻控制栏架构（`macosTopControlsReservedHeight = 38.0`），统筹系统红绿灯、全局导航与当前页面的交互组件：

1. **单一顶部控制区原则（Single Persistent Control Zone Principle）**：
   - **核心设计约束**：**所有页面的控制组件必须统一放置在顶部预留的常驻控制区，严禁在内容区二次划分区域用于显示控制组件**。
   - 绝不允许在内容区域（Content Area）额外叠加、浮动或划分出第二层局部工具栏（Secondary Floating / Segmented Toolbar）。
   - 当页面处于常驻顶栏模式（`MacosPersistentToolbarScope.hasToolbar(context) == true`）时，所有局部标题栏、章节切换栏、排版/目录操作栏等次级工具条一律彻底移除。内容区正文直接从标准上边距（`tokens.spaceLg`）开始排布，保持原生 macOS 桌面应用的清爽通透。

2. **顶栏三段式通道架构与动态挂载机制**：
   - **左侧导航通道（Left Zone）**：
     - 系统红绿灯避让区（`x = 0..78pt`）；
     - 侧边栏折叠/展开按钮（26×26pt，`HugeIcons.strokeRoundedSidebarLeft`）；
     - 历史记录【返回】与【前进】导航按键（26×26pt，`MacosNavArrowIcon`）。
   - **中间内容/控制通道（Middle Zone, `macosToolbarMiddleProvider`）**：
     - 根级别（如 Home 首页）展示多视角切换分段栏（`All | Books | Podcast`）；
     - 子页面（如书籍阅读器 `BookReaderScreen`）挂载该页面的核心控制台（如章节切换 `<` / `>` 按键、当前章节标题、章节阅读进度 `1 / 20` 等）；
     - 当子页面提供 `macosToolbarMiddleProvider` 时，应用自动隐藏根切换栏（`All | Books | Podcast`），实现无缝无冲突的上下文切换。
   - **右侧操作通道（Trailing Zone, `macosToolbarTrailingProvider`）**：
     - 根级别（如 Home 首页）展示全局添加按键（`+`）；
     - 子页面动态挂载专属操作组件（例如：阅读界面的阅读排版 `Aa`、目录 `BookOpen`、听书播放器 `Headphones`，或书籍详情页的更多操作 `...` 菜单）；
     - 挂载专属操作组件时，自动替换根级别的 `+` 按键。

3. **页面生命周期与顶栏状态清理**：
   - 页面挂载顶栏组件（Middle / Trailing）时，应在 `dispose()` 中通过 `Future.microtask` 清理重置为 `null`；
   - 路由压栈切换时（如阅读器打开全屏播放器），主动清理或检测当前路由状态（`isCurrent`），并在返回恢复时重新挂载。

## 6. 色彩系统

页面只能通过 `ColorScheme`、`AppColors` 的语义值或上下文扩展取色：

```dart
final scheme = Theme.of(context).colorScheme;
context.appBackground;
context.appSurface;
context.appSurfaceHighlight;
context.appTextPrimary;
context.appTextSecondary;
```

颜色职责：

- `surface`：页面底色。
- `surfaceContainer`：标准内容表面。
- `surfaceContainerHighest`：提升或强调表面。
- `onSurface`：主要文本与图标。
- `onSurfaceVariant`：次级文本与图标。
- `primary`：CTA、选中、收藏、当前状态和可交互强调。

禁止：

- 在页面中新增 literal blue/green 表示状态。
- 用 `primary` 给普通标题着色。
- 用透明度过低的灰色承担正文。

正文与背景目标对比度不低于 4.5:1；较大的图标和控件边界不低于 3:1。

## 7. 播放器沉浸色规则

播放器采用深色沉浸规则：

1. 封面色只用于背景渐变、ambient surface 和歌词面板氛围。
2. Now Playing 会把任意封面色归一化为深色背景，并固定使用 `AppColors.textPrimary` / `textSecondary` 作为前景；不得因 App 的 light theme 变回浅色播放器。
3. 主播放按钮使用高对比的中性白色圆形，进度使用白色；全局 `ColorScheme.primary` 只标记已启用的状态，例如自定义倍速和生效中的定时关闭。
4. 封面色不得覆盖或临时替换全局 `primary`。
5. 正文预览使用封面衍生的 immersive surface，但正文仍必须满足可读性要求。
6. 如果 CTA 与周围背景视觉冲突，应增加中性承载层或调整 ambient surface；不要生成新的临时品牌色。

这套规则保证播放器具备 Spotify 式的深色层级，同时把品牌绿保留给明确的状态反馈。

## 8. 页面模板

### 8.1 Tab 根页面

适用：Home、Dictionary、Me。

- 使用 `CollapsingPageScaffold`。
- Large Title 左对齐，滚动后折叠为居中 inline title。
- 页面内容使用标准 gutter。
- MiniPlayer 和 BottomNavigationBar 由 `AppScaffold` 统一提供。

### 8.2 二级页面

适用：词典详情、收藏列表、设置详情。

- 显示返回操作。
- 详情内容优先使用 compact header：`compactHeader: true`。
- 不在内容区再次重复一个 Large Title。
- 嵌套在 Tab navigator 中时，为 MiniPlayer/BottomNavigationBar 保留足够底部滚动空间。

### 8.3 沉浸页面

适用：Now Playing、全屏歌词。

- 可以使用封面衍生背景。
- 使用向下关闭表达从全屏回到 MiniPlayer。
- Now Playing 以封面、章节信息、进度和主控制为第一视觉层级；正文只在底部露出预览入口，完整阅读进入全屏正文。
- 用户开始播放后，封面平滑缩小，正文从底部预览提升为主舞台；暂停时保持该阅读上下文，避免界面来回跳变。
- 主舞台同步正文必须同时保留当前行及前后多行，当前行高亮、上下文降权，不采用一次只显示一句的模式。
- 播放态的章节信息、进度与主控制固定在底部安全区上方，剩余纵向空间优先交给同步正文。
- 内容必须可纵向滚动，窄屏不能压缩主控或产生横向溢出。
- 控件尺寸、字体角色和状态色规则仍服从全局设计系统。

### 8.4 临时任务

适用：字幕查词、播放倍速、短设置任务。

- 使用 Bottom Sheet。
- 字幕查词使用可拖拽 sheet，默认约 62%，最大约 94%。
- Sheet 内复用与完整词典相同的 `DictionaryEntryContent`，禁止维护第二套词条 UI。
- 半屏词典采用 explanation-first 信息层级：默认只显示搜索入口，用户主动点击后才展开搜索框；不重复显示 `Dictionary` 页面标题。
- 进入字幕选词状态时立即暂停播放；关闭选词或词典后不自动恢复，由用户明确继续播放。

## 9. 共享组件

### `AppSurface`

用于语义表面。优先传 `level`，只有确有动态沉浸色时才传 `color`。

### `AppSearchField`

统一 52 高度、搜索图标、加载态和提交行为。Dictionary 根页、详情页和半屏词典必须复用。

### `AppSectionHeader`

统一 Section 标题与尾部操作。不要在页面中重新拼 `Row + Text + TextButton`。

### `CollapsingPageScaffold`

统一 Tab 根页面标题和二级 compact header。Large Title 的字号和字重在这里维护。

### `DictionaryEntryContent`

完整页与半屏词典共用的内容组件。它负责词头、音标、释义、上下文例句、解释和来源层级。

组件尚未覆盖的通用模式，应优先补到 `lib/presentation/widgets/design_system/`，再供页面使用。

## 10. 词典内容规则

词典详情的顺序固定为：

1. 词头、收藏
2. 核心释义
3. Short explanation
4. Long explanation
5. Other forms chips
6. US/UK 发音
7. `From your audiobook` 上下文例句
8. 来源

规则：

- 释义使用 `bodyLarge` 和 regular weight，不把正文做成标题。
- 上下文例句使用独立 elevated surface。
- Short explanation 和 Long explanation 使用相同的 section 排版，默认完整展示。
- 半屏与完整页展示同一份完整词条内容，不得按容器尺寸裁剪释义或解释；差异只来自可用视口和滚动位置。
- 发音和书中上下文必须保留，但排在解释内容之后，避免低频功能阻挡主要阅读任务。
- 收藏应保存 book、chapter、paragraph、line、selection 和 audio timestamp 上下文。
- 有时间戳时提供回播入口。

## 11. Do / Don’t

### Do

```dart
final design = context.appDesign;
final scheme = Theme.of(context).colorScheme;

// 1. 表面、间距与圆角语义化
AppSurface(
  padding: EdgeInsets.all(design.spaceLg),
  child: Text(
    title,
    style: Theme.of(context).textTheme.titleMedium,
  ),
);

// 2. 图标使用 HugeIcons Stroke / Rounded，触控热区保证 >= 44
IconButton(
  icon: const HugeIcon(
    icon: HugeIcons.strokeRoundedSettings01,
    size: 24,
    color: scheme.onSurface,
  ),
  onPressed: () => _openSettings(),
);

// 3. 结构分割线使用 1px #E3E3E1 语义 token
Divider(
  height: 1,
  thickness: 1,
  color: AppColors.divider, // #E3E3E1
);
```

### Don’t

```dart
// 1. 硬编码间距、随机灰色、非标圆角与排版字面量
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: const Color(0xFF292929),
    borderRadius: BorderRadius.circular(10), // 非标圆角
  ),
  child: const Text(
    'Title',
    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
  ),
);

// 2. 图标风格生硬或触控热区过小
GestureDetector(
  onTap: () => _openSettings(),
  child: const Icon(Icons.settings, size: 16), // 热区不足 44，非 HugeIcons 风格
);

// 3. 随手写粗细不一或未经语义化的分割线
Container(
  height: 2, // 非 1px
  color: Colors.grey.shade400,
);
```

后一种写法重新定义了间距、颜色、圆角、图标与分割线，无法通过主题统一演进。

## 12. 新增或修改 UI 的流程

1. 确认需求属于现有页面模板还是需要新模板。
2. 先查 `ThemeData` 和 `design_system/` 是否已有对应角色。
3. 使用现有 token 完成组件；不要先写 magic number 再“以后抽取”。
4. 如果需要新 token，说明它的语义、使用范围以及为什么现有 token 不适合。
5. 同时验证 dark/light、常规/窄屏和 130% text scale。
6. 更新或新增 widget/golden test。
7. 运行：

```bash
flutter analyze
flutter test
git diff --check
```

## 13. Review checklist

提交 UI 变更前逐项检查：

- [ ] UI chrome 使用系统字体，阅读字体没有泄漏到控件。
- [ ] 图标统一使用 HugeIcons Stroke / Rounded 风格，触控热区 ≥ 44×44。
- [ ] 结构分割线使用 1px `#E3E3E1`，桌面侧边栏分割线实现物理窗口全高边界贯通（y=0 贯穿到底）。
- [ ] 圆角仅使用 8 / 12 / 16 / pill 语义 token，无非标魔数。
- [ ] 页面标题使用正确的 root/detail/immersive 模板。
- [ ] Large Title 全程保持 700 weight。
- [ ] 页面 gutter 来自 `pageInsetFor()`。
- [ ] 间距只使用 4/8/12/16/24/32 scale。
- [ ] 没有新增页面级 literal color。
- [ ] Card、TextField、Section header 没有绕开共享实现。
- [ ] 表面没有无意义嵌套，正文没有被整块卡片包裹。
- [ ] Player 的 cover-derived color 没有替换 global primary。
- [ ] Bottom Sheet 展开、滚动和键盘状态正常。
- [ ] dark/light、窄屏、130% text scale 无溢出。
- [ ] `flutter analyze` 和相关测试通过。

## 14. 当前覆盖、已知偏离与后续约束

### 14.1 已落地的基础能力

- ThemeExtension tokens
- UI/阅读字体分离
- Material component themes
- `AppSurface`、`AppSearchField`、`AppSectionHeader`
- HugeIcons Stroke / Rounded 图标体系与 `AppNavigationIcon`
- 1px `#E3E3E1` 分割线规范与桌面端全高边界贯通（Full-Height Boundary Spanning）
- 四层语义圆角尺度体系（8/12/16/pill）
- Settings 的 `SettingsGroup`、`SettingValueRow`、`ServiceStatusCard`、`ReadinessBadge`、反馈与空错态组件
- Large/compact header
- Dictionary 全页与半屏内容复用
- Player ambient color / global primary 分工
- Home、Dictionary、Me 的主要 gutter 收口

这里的“已落地”表示基础能力已有单一实现和真实消费者，不表示整个历史代码库已经完成 token 化。

### 14.2 已知偏离与迁移 backlog

| 区域 | 当前偏离 | 收敛规则 |
| --- | --- | --- |
| Home、Me 的部分私有组件 | 仍存在页面内 `TextStyle`、局部 padding 和 radius | 下次触碰对应组件时迁入 TextTheme、token 或共享组件 |
| Player 的部分控制与 Lyrics 私有组件 | 仍有组件内部尺寸和排版字面量 | 区分媒体专用尺寸与通用 token；可复用项进入 immersive 组件层 |
| 空态与错误态 | Settings 已统一，其他历史页面仍有私有实现 | 新页面复用共享状态组件，旧页面在触碰时迁移 |
| 视觉回归 | Settings root 已覆盖双主题 golden，其他核心页面仍未覆盖 | 新增核心流程时同步增加稳定、固定状态的 golden |
| 自动约束 | 尚无 UI magic-number CI lint | 增加针对 spacing、radius、font 和 literal color 的检查 |

偏离清单的维护规则：

1. 新代码不得以“旧页面已有硬编码”为理由继续扩散。
2. 触碰表中区域时，应同步减少对应负债；若无法减少，在 PR 中说明原因。
3. 偏离被代码清零后，在同一提交中移除表项。
4. 新发现的系统性偏离应先登记，再决定立即修复或安排迁移。

### 14.3 后续能力

- 通用 ListRow、EmptyState、ErrorState、ImmersiveScaffold
- 核心页面 golden tests
- CI 中对新增 magic spacing/radius/font/color 的检查
- light mode 和高对比度的完整视觉验收

后续项不是绕过现行规范的理由。新增页面应从第一天使用已存在的 token、Theme 和共享组件。
