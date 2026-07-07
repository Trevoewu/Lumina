# Lumina 词典与收藏单词实施计划

## 1. 产品目标

为 Lumina 增加一个轻量、独立的英语词典能力：

```text
阅读时选择单词，或在查词页输入单词
→ 查询 Vocabulary.com
→ 将成功结果永久缓存到本地
→ 再次查询时直接读取缓存
→ 用户可收藏单词
→ 查词页展示收藏单词卡和最近查询
```

### 1.1 核心原则

- 词典查询是主功能，收藏是辅助功能。
- Vocabulary.com 成功结果永久保存，缓存命中不再次联网。
- 书籍上下文只在从歌词查词时存在。
- 收藏表示保存单词。
- 词典内容使用单面布局，直接展示完整核心信息。
- 原有书籍全文搜索迁移到主页工具栏并继续保留。
- Vocabulary.com Provider 与业务隔离，解析失效时不影响已有缓存。

## 2. MVP 范围

- 每行歌词可选择单词或短语。
- 选择菜单包含系统复制、查词和 Ask AI。
- 底部“搜索”页改造成“查词”页。
- 支持手动输入英语单词或短语。
- 直接移植 Bob Vocabulary.com 插件的请求和 HTML 解析方式。
- 解析词性、定义、其他词形、short explanation、long explanation 和 US / UK 音标。
- 成功结果永久缓存。
- `notFound` 结果缓存 7 天。
- 同一单词并发查询合并成一个请求。
- 收藏、取消收藏和收藏单词列表。
- 从歌词收藏时保存当前行和书籍来源快照。
- 最近查询列表。
- 单面词典卡。
- 发音播放和首次播放后的本地音频缓存。
- 原书全文搜索迁移到主页工具栏。
- Vocabulary.com 未找到或解析失败时可通过 OpenAI-compatible 接口生成解释。
- 设置页可管理 DeepSeek、Z.AI 和自定义 OpenAI-compatible Provider。
- 每个 Provider 独立保存 API Key，并通过 `/models` 自动发现可用模型。
- 数据迁移、缓存、解析和核心交互测试。

## 3. 信息架构

底部导航调整为：

```text
主页 | 查词 | 我的
```

- 主页：书籍、最近阅读、播放器和原书全文搜索。
- 查词：单词输入、词典结果、收藏单词和最近查询。
- 我的：设置、缓存、日志和现有配置。

代码调整：

- `SearchScreen` 重命名为 `DictionaryScreen`。
- 原 `SearchScreen` 中书籍、章节和正文搜索抽成 `BookSearchScreen`。
- 主页工具栏新增搜索按钮，打开 `BookSearchScreen`。
- `AppScaffold` 第二个底部导航项改为“查词”。
- 查词页和主页书籍搜索入口必须在同一版本发布。

## 4. 查词页

### 4.1 默认状态

```text
查词

[ 输入英文单词或短语 ]

收藏单词
[Top 3 收藏摘要]                         [查看全部]

查询历史
[Top 3 历史摘要]                         [查看全部]
```

规则：

- 输入框默认获得焦点仅限用户主动进入查词页时。
- 输入防抖 250–350ms，但不在用户仍输入时发请求。
- 按 Enter、搜索按钮或选择建议后执行查询。
- 空查询首页只显示收藏和查询历史各自最新的 Top 3，避免列表无限增长。
- 收藏列表默认按 `favoritedAt` 倒序。
- 最近查询按 `lastAccessedAt` 倒序，并排除当前显示词条。
- Favorites 和 History 各有独立二级页面，通过“查看全部”访问完整列表。
- 从二级页面打开词条并取消收藏后，返回时立即刷新列表。
- 收藏为空时显示“在歌词中选择单词，或在上方查词后收藏”。

### 4.2 查询结果状态

- `loading`：保留输入框，只在结果区域显示局部加载。
- `cached`：立即展示本地结果，不显示网络等待。
- `success`：展示并写入本地缓存。
- `notFound`：已选择兼容模型时生成普通词典解释，否则允许修改查询词或打开 Vocabulary.com 页面。
- `offlineMiss`：提示无网络且本地未缓存。
- `parseError`：兼容模型已配置时生成解释；歌词查词使用书籍上下文，手动查词使用普通词典解释。
- `networkError`：支持重试，不写错误缓存。

### 4.3 收藏单词摘要

列表中的收藏卡保持简洁：

- 单词。
- US 或首选音标。
- 第一条精简定义或 short explanation 摘要。
- 有上下文时显示一行书籍上下文。
- 来源书名。
- 发音按钮。
- 已收藏图标。

点击摘要打开完整词典详情。

## 5. 单面词典卡

布局参考 Vocabulary.com 插件结果页，但完全使用 Lumina 的主题、字体、圆角、Surface 和强调色。

### 5.1 固定信息顺序

1. 来源栏。
2. 单词或短语。
3. US / UK 音标与独立发音按钮。
4. 词性及对应定义。
5. `Other forms`。
6. `书籍上下文`，仅当本次查询来自歌词或收藏记录包含上下文时显示。
7. `short explanation`。
8. `long explanation`。
9. Vocabulary.com 来源链接和归属信息。

书籍上下文必须位于 `short explanation` 之前。

### 5.2 视觉规则

- 来源栏使用次级文字。
- 单词使用页面最大字号和主文字色。
- 不复制 Vocabulary.com 的绿色品牌头部。
- US / UK 发音按钮沿用播放器图标风格。
- 区块标题使用次级文字，正文使用主文字。
- 词性使用次级颜色，定义使用主文字。
- Other forms 使用主题强调色。
- 书籍上下文使用稍亮的 Surface 容器或左侧强调线。
- 上下文中高亮本次选中的文字。
- short explanation 完整展示。
- long explanation 默认显示 4–6 行，支持展开全文。

### 5.3 收藏操作

- 详情页右上角使用书签图标。
- 未收藏时点击：创建 `FavoriteWord`。
- 已收藏时点击：取消收藏，但不删除词典缓存。
- 取消收藏可使用 Snackbar 撤销，不需要危险操作确认。
- 收藏状态变化不影响词典数据。

## 6. 歌词选词与书籍上下文

### 6.1 行级选词模式

移动端不以系统拖动选区作为主要入口：

- 普通点击继续播放当前行。
- 长按任意歌词行进入该行的选词模式。
- 当前行按单词、连字符词、数字和标点拆成轻量 token 高亮。
- 点击 token 可选中或取消，按住滑动可连续选择一段 token。
- token 保持原歌词字号、行高和接近原始的空格宽度，避免进入模式后大幅重排。
- 其他行降低亮度，长行仍可纵向滚动查看。
- 按下时当前行轻微缩放并显示底色；进入模式时触发触觉反馈和淡入尺寸动画。
- MVP 不支持跨行选择。

### 6.2 选词操作栏

选词操作栏紧跟在当前选中行下方显示：

- 取消：退出选词模式。
- 当前选中文字摘要。
- 查词：使用 Vocabulary.com，并在必要时自动降级。
- Ask AI：跳过 Vocabulary.com，主动调用当前模型。

系统复制和桌面文本选择仍作为辅助能力保留。

### 6.3 从歌词查词

```text
选择单词
→ 点击查词
→ 打开查词详情或底部面板
→ 查询缓存或 Vocabulary.com
→ 展示书籍上下文
→ 用户可收藏
```

也可以主动绕过 Vocabulary.com：

```text
选择单词、短语或文本
→ 点击 Ask AI
→ 直接调用当前选择的 Provider / Model
→ 结合书名、章节和当前行解释
→ 永久缓存并在词典详情页展示
```

Ask AI 不先请求 Vocabulary.com。未配置 Provider、API Key 或 Model 时显示明确配置错误。

从歌词收藏时保存：

- 当前行文本。
- 选中范围。
- 书籍和章节标题快照。
- bookId、chapterId、paragraphId 和 lineId。
- 当前行音频起止时间。

### 6.4 重复收藏上下文规则

每个词条只保留一个收藏记录：

- 已收藏记录没有上下文，而新收藏来自歌词：补充当前上下文。
- 已收藏记录已经有上下文：默认保留原上下文。
- 详情页提供“更新为当前上下文”。
- 不静默覆盖用户已保存的上下文。

## 7. Vocabulary.com 接入

### 7.1 参考实现

参考 [Oops418/bob-plugin-vocabulary.com](https://github.com/Oops418/bob-plugin-vocabulary.com)，将其 TypeScript 请求和 HTML 解析逻辑移植为 Dart。

插件许可证文件为 MIT。直接复用解析逻辑时，在项目第三方声明中保留其版权和许可证。

### 7.2 请求

```text
GET https://www.vocabulary.com/dictionary/definition.ajax
    ?search={word}
    &lang=en
```

使用现有 Dio，并通过 `queryParameters` 编码：

```dart
await dio.get<String>(
  'https://www.vocabulary.com/dictionary/definition.ajax',
  queryParameters: {'search': normalizedTerm, 'lang': 'en'},
);
```

规则：

- 只支持英语。
- 只有用户主动提交查询才访问网络。
- 不扫描书籍或批量预加载。
- 同一规范化单词的并发请求合并为一个 Future。
- 设置连接和响应超时。
- 429 或 5xx 有限退避，不无限重试。
- 缓存命中时不执行网络请求。

### 7.3 HTML 解析

增加 Dart `html` 直接依赖，按插件逻辑提取：

- `.wordnotfound-wrapper`
- 词性和定义列表
- Other forms
- short explanation
- long explanation
- US IPA
- UK IPA

领域模型：

```dart
class DictionaryEntry {
  final String id;
  final String provider;
  final String language;
  final String displayWord;
  final String normalizedTerm;
  final List<DictionaryPhonetic> phonetics;
  final List<DictionaryPart> parts;
  final List<String> otherForms;
  final String? shortExplanation;
  final String? longExplanation;
  final String sourceUrl;
  final int parserVersion;
}
```

解析约束：

- CSS selector 集中放在 `VocabularyComParser`。
- Parser 有独立版本号。
- 核心释义为空时不能写成功缓存。
- 单元测试使用精简、脱敏的本地 HTML fixture。
- 自动化测试不能依赖线上 Vocabulary.com。

### 7.4 上游风险

`definition.ajax` 是插件使用的未公开 HTML 接口，并非 Vocabulary.com 承诺稳定的公共 API。

Vocabulary.com 的[使用条款](https://www.vocabulary.com/terms/)对自动抓取和系统性建立数据库有限制。当前方案按产品决定直接接入，但保持以下边界：

- 只处理用户逐次主动查询。
- UI 显示 Vocabulary.com 来源和归属信息。
- Provider 可以独立关闭或替换。
- 对外分发或商业发布前重新核验条款。

### 7.5 OpenAI-compatible 解析降级

Vocabulary.com 未找到词条，或返回成功但 HTML Parser 无法提取核心释义时，启用兼容模型降级。正常缓存、正常解析和普通网络错误不调用模型。

请求包含：

- 选中的单词。
- 从歌词查词时附加书籍名称、章节名称和当前歌词行。
- 手动查词没有书籍上下文时，只请求普通词典解释。

设置分为两个二级页面：

- `LLM Provider`：添加 DeepSeek、Z.AI 或自定义 OpenAI-compatible Provider。每个 Provider 的 API Key 独立保存到系统安全存储；自定义 Provider 还需填写名称与 Base URL。
- `Model`：并行请求所有已配置 Provider 的 `GET /models`，按 Provider 与 API 域名分组，用户选择其中一个 Provider / Model 组合。

内置端点：

- DeepSeek：`https://api.deepseek.com`。
- Z.AI：`https://api.z.ai/api/paas/v4`。
- 自定义：用户填写不带末尾 `/` 的 OpenAI-compatible Base URL。

旧版单一 API Key、Base URL 和 Model 配置首次读取时自动迁移为一个 Provider，不丢失已有密钥与模型选择。

通过 OpenAI-compatible `POST /chat/completions` 请求 JSON 输出，返回词性、当前语境含义、short explanation 和 long explanation。模型解释按 Base URL、模型和上下文生成独立缓存键，同一上下文再次查询不重复请求。

## 8. 永久缓存

### 8.1 缓存规则

- `success` 永久缓存，无自动过期。
- 成功缓存命中时绝不联网。
- `notFound` 缓存 7 天。
- 网络错误、超时、429、5xx 和解析失败不写缓存。
- 用户可在详情页手动刷新单个词条。
- 手动刷新成功后更新缓存，但不会影响收藏上下文。

### 8.2 规范化缓存键

唯一键：

```text
(provider, language, normalizedTerm)
```

规范化：

```text
trim
→ Unicode 标准化
→ 转小写
→ 合并连续空白
→ 保留内部 apostrophe 和连字符
```

MVP 不自动词形还原，避免把不同词形错误合并。

### 8.3 查询流程

```text
用户提交查询
→ 规范化输入
→ 查询 DictionaryEntries
→ success 命中：更新 lastAccessedAt，直接返回
→ 有效 notFound 命中：若模型已配置则读取或生成模型解释，否则显示未找到
→ 未命中：检查 in-flight 请求
→ 已有同词请求：等待同一个 Future
→ 没有请求：访问 Vocabulary.com
→ 解析成功：事务写入缓存
→ 返回结果
```

## 9. 发音

参考插件支持：

- Google Translate TTS
- 有道词典发音

实现要求：

- 通过 URI 参数编码单词。
- 修复参考插件 URL 中可能存在的多余右花括号。
- 查询词典时只保存音标和候选发音 URL。
- 第一次播放时下载音频并保存到应用缓存目录。
- 后续优先播放本地文件。
- 发音失败不影响词典展示。
- 不自动调用 Lumina 的付费远程 TTS。

设置页可增加：

```text
[开关] 查询后自动发音
       打开新词条时自动播放首选发音
```

默认值：

```text
dictionary_auto_pronounce_enabled = true
```

同一词条在同一次页面停留期间只自动播放一次。

## 10. 数据模型

当前 Drift `schemaVersion` 为 3。MVP 升级到 4，并先生成 schema 3 快照。

### 10.1 DictionaryEntries

```dart
class DictionaryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get provider => text()(); // vocabulary_com
  TextColumn get language => text()(); // en
  TextColumn get normalizedTerm => text()();
  TextColumn get displayWord => text()();
  TextColumn get status => text()(); // success | not_found

  TextColumn get phoneticsJson => text().nullable()();
  TextColumn get partsJson => text().nullable()();
  TextColumn get otherFormsJson => text().nullable()();
  TextColumn get shortExplanation => text().nullable()();
  TextColumn get longExplanation => text().nullable()();
  TextColumn get sourceUrl => text()();
  TextColumn get attribution => text()();

  TextColumn get usAudioUrl => text().nullable()();
  TextColumn get ukAudioUrl => text().nullable()();
  TextColumn get usAudioPath => text().nullable()();
  TextColumn get ukAudioPath => text().nullable()();

  IntColumn get parserVersion => integer()();
  IntColumn get fetchedAt => integer()();
  IntColumn get expiresAt => integer().nullable()();
  IntColumn get lastAccessedAt => integer()();
  IntColumn get accessCount => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
```

索引：

```text
UNIQUE(provider, language, normalizedTerm)
(lastAccessedAt)
```

### 10.2 FavoriteWords

```dart
class FavoriteWords extends Table {
  TextColumn get id => text()();
  TextColumn get dictionaryEntryId => text()();

  TextColumn get contextText => text().nullable()();
  IntColumn get selectionStart => integer().nullable()();
  IntColumn get selectionEnd => integer().nullable()();

  TextColumn get sourceBookId => text().nullable()();
  TextColumn get sourceBookTitle => text().nullable()();
  TextColumn get sourceChapterId => text().nullable()();
  TextColumn get sourceChapterTitle => text().nullable()();
  TextColumn get sourceParagraphId => text().nullable()();
  TextColumn get sourceLineId => text().nullable()();
  IntColumn get audioStartMs => integer().nullable()();
  IntColumn get audioEndMs => integer().nullable()();

  IntColumn get favoritedAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

索引：

```text
UNIQUE(dictionaryEntryId)
(favoritedAt)
```

词典缓存和收藏分离：取消收藏只删除 `FavoriteWords`，不会删除 `DictionaryEntries`。

### 10.3 书籍删除

- 收藏记录保留上下文和标题快照。
- 删除书籍时不删除收藏词。
- 来源 ID 对应记录不存在时隐藏“返回原文”。
- 不要求为收藏记录建立数据库外键级联。

## 11. 数据访问接口

### 11.1 DictionaryCacheRepository

- `lookup`
- `getCachedEntry`
- `saveSuccess`
- `saveNotFound`
- `touchEntry`
- `refreshEntry`
- `watchRecentEntries`
- `updateAudioPath`

### 11.2 FavoriteWordRepository

- `addFavorite`
- `removeFavorite`
- `isFavorite`
- `watchFavorites`
- `getFavorite`
- `updateContext`

收藏写入必须保证 `dictionaryEntryId` 唯一。并发收藏使用事务或 conflict update。

## 12. 代码结构

```text
lib/
  core/
    dictionary_preferences.dart
  domain/
    models/
      dictionary_entry.dart
      favorite_word.dart
      lyric_selection.dart
  data/
    dictionary/
      dictionary_cache_repository.dart
      dictionary_provider.dart
      openai_compatible_explanation_provider.dart
      vocabulary_com_parser.dart
      vocabulary_com_provider.dart
    repositories/
      favorite_word_repository.dart
  services/
    dictionary_audio_service.dart
  presentation/
    screens/
      dictionary/
        dictionary_screen.dart
        word_detail_screen.dart
      search/
        book_search_screen.dart
    widgets/
      dictionary_card.dart
      favorite_word_tile.dart
      lyric_lookup_sheet.dart
```

职责：

- `VocabularyComProvider` 只负责网络请求。
- `VocabularyComParser` 只负责 HTML 解析。
- `OpenAiCompatibleExplanationProvider` 只负责上下文解释降级。
- `DictionaryCacheRepository` 负责缓存优先、永久保存和请求合并。
- `FavoriteWordRepository` 只负责收藏状态和上下文快照。
- `DictionaryAudioService` 管理发音 URL、下载和本地播放。
- Widget 不直接操作 Dio 或 Drift 表。

## 13. 视觉规范

继续复用：

- `CollapsingPageScaffold`
- `AppColors`
- 当前 Surface、圆角和文字层级
- 播放器约 220ms 的过渡节奏
- Material Symbols 图标
- 设置页 `_buildSwitchTile`

收藏使用主题强调色；取消收藏使用可撤销 Snackbar。

## 14. 分阶段实施

### Phase 0：技术原型

- 验证单击播放与双击、长按选择共存。
- 验证 Vocabulary.com HTML 能被 Dart Parser 解析。
- 保存精简 fixture 并确定 parser version 1。
- 验证单面词典卡在手机和桌面布局。

完成标准：手势、解析和布局风险均得到验证。

### Phase 1：数据库和词典缓存

- 增加 Dart `html` 直接依赖。
- 生成 Drift schema 3 快照。
- schema 3 → 4。
- 新增 DictionaryEntries、FavoriteWords 和索引。
- 实现 Provider、Parser、请求合并和永久缓存。
- 实现 OpenAI-compatible Parser 失败降级和上下文缓存。
- 实现最近查询元数据。

完成标准：同一单词首次联网，后续离线可读取完整结果。

### Phase 2：查词页和收藏

- `SearchScreen` 改为 `DictionaryScreen`。
- 实现输入、查询状态和单面词典卡。
- 实现收藏、取消收藏、收藏列表和最近查询。
- 实现详情页和手动刷新。
- 同时把原书搜索迁移到主页。

完成标准：查词与收藏闭环可独立工作，书籍搜索无回归。

### Phase 3：歌词选词

- 新增 `LyricSelection`。
- 改为逐行选择。
- 实现系统复制、查词和 Ask AI 菜单。
- 从歌词查词时带入当前行和来源。
- 保留移动端整行点击播放。

完成标准：用户可以从阅读内容直接查词并收藏上下文。

### Phase 4：发音和完善

- 实现 Google / 有道发音 URL。
- 首次播放后保存本地音频。
- 设置页增加查询后自动发音。
- 设置页增加 LLM Provider 管理与自动模型发现页面。
- 键盘操作、屏幕阅读器和响应式布局。
- 错误恢复、日志和 Provider 开关。

## 15. 测试计划

### 15.1 单元测试

- 单词规范化。
- 成功、notFound 和结构变化 HTML fixture。
- 成功缓存永久命中且不联网。
- notFound 7 天后重新查询。
- 并发同词查询只有一个请求。
- 网络和解析错误不写缓存。
- Parser 失败时将书名、章节和当前句子传给兼容模型。
- 相同模型和上下文的解释命中本地缓存。
- 多 Provider 分别保存 API Key，并聚合 `/models` 返回结果。
- 旧版单 Provider 配置迁移后保留 API Key 和模型。
- lastAccessedAt 和 accessCount 更新。
- 收藏唯一约束。
- 取消收藏不删除词典缓存。
- 上下文补充和显式更新规则。
- schema 3 → 4 与 `verifySelfIntegrity`。

### 15.2 Widget 测试

- 查词页空、加载、缓存、成功和错误状态。
- 单面卡片信息顺序。
- 书籍上下文位于 short explanation 前。
- 无上下文查询不显示空上下文区块。
- long explanation 展开。
- 收藏、取消收藏和撤销。
- 收藏列表和最近查询排序。
- 单击播放与选择手势。
- 原书搜索入口存在。

### 15.3 音频测试

- 发音 URL 正确编码。
- 首次播放下载本地文件。
- 后续播放不联网。
- 自动发音同次页面只执行一次。
- 发音失败不影响词典卡。
- 不调用付费远程 TTS。

### 15.4 集成测试

```text
在歌词中选择单词
→ 首次查询 Vocabulary.com
→ 保存永久缓存
→ 收藏并保存书籍上下文
→ 在查词页看到收藏卡
→ 再次查询同词且网络请求数不增加
→ 取消收藏但缓存仍存在
→ 离线重新查询并展示缓存结果
```

## 16. 发布与回滚

- schema 4 只新增表和索引。
- 查词入口使用 feature flag。
- Vocabulary.com Provider 可独立关闭或替换。
- OpenAI-compatible 降级未配置时保持原 Parser 错误行为。
- Parser 失效时保留已有缓存。
- 手动打开 Vocabulary.com 页面作为降级。
- 查词页与主页书籍搜索入口同版本上线。
- 自动发音不触发付费请求。
- 对外发布前重新核验 Vocabulary.com 使用条款。

## 17. MVP 完成定义

- 用户能手动输入英语单词并查询。
- 用户能从当前歌词行稳定选择单词或短语。
- 移动端整行点击播放无回归。
- 首次查询后能够永久本地命中。
- 离线时能够展示曾查询过的词条。
- 单面卡片顺序符合设计要求。
- 用户能收藏、取消收藏并查看收藏列表。
- 从歌词收藏时能保存并显示书籍上下文。
- 取消收藏不会删除词典缓存。
- 最近查询正确更新。
- 原书全文搜索仍有明确入口。
- 词典解析、缓存、迁移和核心交互均有测试。

## 18. 已确定决策

- 底部第二项命名为“查词”。
- Vocabulary.com 是首发词典来源。
- 直接移植 Bob 插件的请求与 HTML 解析方式。
- 成功查询永久缓存。
- 首发只支持英语。
- 收藏是普通书签语义。
- 每个词条只有一个收藏记录。
- 收藏可以保存一个书籍上下文快照。
- 书籍上下文显示在 short explanation 前。
- 词典卡为单面布局。
- 自动发音默认开启。
- 兼容模型支持 DeepSeek、Z.AI 和自定义 Provider。
- 模型必须从已配置 Provider 的远端模型列表中选择。
