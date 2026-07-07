# Settings & AI Services Refactor Plan

本文档定义 Lumina 设置页重构的产品模型、交互契约、状态迁移和实施顺序。目标不是单纯重画页面，而是让 TTS Provider 与 LLM Provider 在保持能力差异的同时，遵循同一套可预测的操作逻辑。

实现 UI 时必须同时遵循 [Lumina UI Design System](ui_design_system.md)。

## 1. 背景与问题

当前设置页把“选择当前服务”“配置凭据”“管理 Provider”“选择 Model/Voice”混在同一层，同时 TTS 与 LLM 使用不同交互：

| 行为 | TTS 当前实现 | LLM 当前实现 |
| --- | --- | --- |
| Provider 含义 | 代码中注册的内置实现 | 用户保存的连接配置 |
| 选择入口 | Settings 内 PopupMenu | Provider 管理页 + 独立 Model 页面 |
| 激活时机 | 点击菜单项立即激活 | 选择 Model 时隐式切换 Provider |
| API Key | 当前 Provider 的 Bottom Sheet | Provider 编辑 Bottom Sheet |
| Model | 本地模型管理、固定模型或 Provider 内部策略 | 独立页面展示所有 Provider 的模型 |
| Voice | 根设置页之外的 Voice Library | 不适用 |
| 根页摘要 | 当前 TTS Provider | LLM Provider 配置数量 |
| 状态表达 | 下载、API Key、能力文本分散显示 | Provider、Model、连接状态分开显示 |

直接改 UI 无法解决这些问题。必须先统一领域术语、激活规则和持久化状态。

## 2. 目标

### 2.1 用户目标

用户应该能够回答：

1. 当前 TTS 使用哪个 Provider、Model 和 Voice？
2. 当前词典解释使用哪个 Provider 和 Model？
3. 当前配置是否可用？如果不可用，下一步该做什么？
4. 切换 Provider 后，之前选择的 Model/Voice 是否会恢复？
5. 测试连接、下载模型或更新密钥会不会意外切换当前配置？

### 2.2 工程目标

- TTS 和 LLM 使用相同的页面结构与选择语义。
- Provider 配置、当前选择和运行时 readiness 分离。
- Model/Voice 按 Provider 保存，不再使用容易错配的全局选择。
- Settings 根页面只展示摘要和导航，不承担复杂配置。
- 页面使用共享组件，但 TTS 与 LLM 控制器保持独立，避免“万能 Provider 抽象”。
- 旧设置无损迁移，已有用户无需重新输入 API Key。

## 3. 非目标

本次重构不包括：

- 改写 TTS 合成或 LLM 请求协议。
- 增加新的云服务 Provider。
- 统一 TTS Provider 和 LLM Provider 的底层接口。
- 改变 API Key 的安全存储方式。
- 重做 Voice Clone、Voice Design 的具体业务流程。
- 重做 Audio Cache、日志和外观页面内部功能。

## 4. 统一术语

### Service

面向用户的能力。目前有：

- `Text to Speech`
- `Dictionary Explanation`

### Provider Definition

代码支持的一类服务实现，例如 Kokoro Local、Fish Audio API、DeepSeek。TTS Provider Definition 来自注册表；LLM 的预置 kind 来自 `LlmProviderKind`。

### Connection Profile

用户可实际使用的一份配置，包含 Provider 类型、显示名称、Base URL 和凭据引用。

- LLM 允许同一种 Provider Definition 创建多个 Connection Profile。
- 当前 TTS 实现大多是一种 Definition 对应一个 Profile，但 UI 不应依赖这个限制。

### Active Configuration

某项 Service 当前使用的完整选择：

```text
TTS = Provider + optional Model + Voice
LLM = Provider Profile + Model
```

### Setup

使 Provider 可工作的前置条件：API Key、本地模型、Base URL 或其他 Provider 专属配置。

### Readiness

配置在当前设备上能否执行真实任务。统一状态：

```dart
enum ServiceReadiness {
  checking,
  ready,
  setupRequired,
  unavailable,
  error,
}
```

`configured` 不等于 `ready`。保存了 API Key 但未选择 Model，仍是 `setupRequired`。

## 5. 核心交互契约

TTS 和 LLM 都必须遵守以下规则：

1. Settings 根页不直接切换 Provider。
2. 点击 Service 行进入完整 Service 页面。
3. Provider 使用全屏选择页，不使用 PopupMenu。
4. 未就绪 Provider 不能因一次点击而立即成为 active。
5. 配置、测试与激活是不同动作。
6. Provider 配置成功后，用户通过 `Use this provider` 明确激活；首次配置且没有其他 active Provider 时可以在成功后自动激活，但必须有明确反馈。
7. Model Picker 只展示当前 Provider 的模型，不允许选择 Model 时隐式切换 Provider。
8. Voice Picker 只展示当前 TTS Provider 的音色。
9. 切换 Provider 时恢复该 Provider 上次使用的 Model/Voice。
10. 删除 active Provider 前必须确认，并明确将回退到哪个 Provider；无法回退时 Service 进入 `setupRequired`。
11. 测试连接失败不清除已保存配置，也不切换 active Provider。
12. Bottom Sheet 只承载单一步骤短任务；包含键盘、多字段、测试和删除的 Provider 配置使用完整页面。

## 6. 新的信息架构

```text
Settings
├── General
│   ├── Language
│   └── Appearance
├── AI Services
│   ├── Text to Speech
│   └── Dictionary Explanation
├── Playback
│   ├── Paragraph Fade-in
│   └── Sleep Timer
├── Storage
│   └── Audio Cache
└── Support
    └── Logs
```

Settings 根页只显示 Service 摘要：

```text
Text to Speech
Fish Audio API · Warm Narrator              Ready  ›

Dictionary Explanation
DeepSeek · deepseek-chat                    Ready  ›
```

摘要优先展示当前配置，不显示“已配置 2 个 Provider”这种管理信息。配置数量属于 Provider 管理页。

Voice Library 从 Settings 根页移入 Text to Speech 页面；Audio Cache 移入 Storage。

## 7. 统一 Service 页面模板

### 7.1 Text to Speech

```text
Text to Speech

┌ Current configuration ─────────────────┐
│ Fish Audio API                         │
│ S2 Pro · Warm Narrator          Ready  │
└────────────────────────────────────────┘

Provider                         Fish Audio API  ›
Model                                  S2 Pro    ›  (仅支持选择时显示)
Voice                            Warm Narrator   ›

Setup
Credentials                              Saved   ›
Connection test                         Passed   ›

Provider capabilities
Preset voices · Voice cloning · Streaming

Advanced
Generation profile                    Quality    ›
Local model                              ...     ›  (本地 Provider)
```

### 7.2 Dictionary Explanation

```text
Dictionary Explanation

┌ Current configuration ─────────────────┐
│ DeepSeek                               │
│ deepseek-chat                   Ready  │
└────────────────────────────────────────┘

Provider                              DeepSeek   ›
Model                           deepseek-chat    ›

Setup
Credentials                              Saved   ›
Connection test                         Passed   ›

Advanced
Base URL                    api.deepseek.com    ›
```

两页结构一致，但根据能力显隐 Model、Voice、Local Model、Generation Profile 等行。

## 8. Provider Picker

Provider Picker 是全屏二级页：

```text
Choose Provider                                      +

CURRENT
✓ Fish Audio API                              Ready

AVAILABLE
  Kokoro Local                        Model required
  Fish Audio Local                    Model required
  MiniMax                              Key required
  Edge TTS                                     Ready
```

统一行为：

- 点击 ready Provider：进入预览/详情，而不是立即静默切换。
- 点击 setup-required Provider：进入 Provider Details。
- 当前 Provider 显示 check 和状态。
- LLM 页面允许 `Add Provider`；TTS 内置 Provider 不允许删除。
- LLM 用户 Profile 支持编辑和删除。
- Provider 列表使用同一 `ProviderOptionTile`，由 adapter 提供差异化状态和操作。

## 9. Provider Details

Provider Details 使用完整页面，结构统一：

```text
Provider Name
Provider kind / host

SETUP
API Key
Base URL
Local Model

STATUS
Last checked
Error details

[Test Connection]
[Save]
[Use this provider]
[Delete Provider]  // 仅可删除的 LLM Profile
```

Provider 专属差异通过 setup adapter 表达：

- API Provider：API Key、Base URL、测试连接。
- Local Provider：模型安装、版本、路径、下载进度。
- 无配置 Provider：只显示能力与 readiness。

保存表单不自动激活。`Use this provider` 仅在 readiness 满足时可用。

## 10. Model 与 Voice 选择

### Model Picker

- 只查询当前 Provider。
- 页面标题包含 Provider 名称。
- 支持刷新、加载、错误和空态。
- 选择 Model 只修改当前 Provider 对应的 Model，不修改 active Provider。
- 切换回 Provider 时恢复上次 Model。

### Voice Picker

- 只展示当前 TTS Provider 的 Voice。
- 当前 Voice 显示 check。
- Voice 同步、克隆和描述生成放在该 Provider 的 Voice 页面中。
- 切换 Provider 后恢复该 Provider 上次选择的 Voice。
- 没有可用 Voice 时，TTS readiness 为 `setupRequired`，页面给出 `Sync voices` 或 `Create voice` 的明确动作。

## 11. 状态模型

不要用一个泛型“万能 Provider Controller”承载所有差异。使用两个独立控制器和共享 view model。

```dart
enum AiServiceKind { tts, dictionaryExplanation }

class ServiceSettingsSummary {
  final AiServiceKind kind;
  final String title;
  final String? providerId;
  final String? providerName;
  final String? modelId;
  final String? voiceId;
  final String? voiceName;
  final ServiceReadiness readiness;
  final String statusLabel;
}

class ServiceSettingsNotice {
  final String message;
  final String? previousProviderName;
}

class ProviderOptionViewData {
  final String id;
  final String name;
  final String subtitle;
  final ServiceReadiness readiness;
  final bool active;
  final bool editable;
  final bool removable;
}
```

`ServiceSettingsSummary` 只表达当前事实，并遵守以下不变量：

- `providerId` 与 `providerName` 必须同时为 null 或同时非 null。
- 两者为 null 表示当前没有 active Provider，不保留已删除 Provider 的悬空引用。
- “刚刚删除了 X”“已回退到 Y”等一次性反馈通过 controller 内存中的 `ServiceSettingsNotice` 表达。
- `ServiceSettingsNotice` 不持久化；重新加载后 summary 仍只显示当前配置。
- “从未配置”和“删除后无可回退”可以共享空 summary，但通过当次 notice 给出不同解释。

Riverpod 控制器：

```text
TtsSettingsController extends AsyncNotifier<TtsSettingsState>
LlmSettingsController extends AsyncNotifier<LlmSettingsState>
```

两者提供一致的 UI 动作名称：

```text
reload()
selectProvider(...)
testProvider(...)
selectModel(...)
```

TTS 额外提供：

```text
selectVoice(...)
installLocalModel(...)
```

LLM 额外提供：

```text
addProvider(...)
updateProvider(...)
removeProvider(...)
```

共享 UI 只依赖 view data 和回调，不依赖 `TtsProvider` 或 `OpenAiCompatibleExplanationProvider` 实例。

## 12. 持久化设计

### 12.1 新设置

在现有 AppSettings 字符串存储上增加版本化映射：

```text
service_settings_schema_version = 1
tts_selected_voice_by_provider_v1 = { providerId: voiceId }
tts_selected_model_by_provider_v1 = { providerId: modelId }
llm_selected_model_by_provider_v1 = { providerId: modelId }
```

Active Provider 暂时保留现有键，减少迁移风险：

```text
TTS: active_provider_id
LLM: openai_compatible_dictionary_active_provider
```

Provider 配置与密钥继续使用现有存储：

```text
openai_compatible_dictionary_providers
ApiKeyStore provider-scoped keys
```

### 12.2 为什么 Model/Voice 必须按 Provider 保存

当前 `active_voice_id` 和 `openai_compatible_dictionary_model` 是全局值。切换 Provider 后可能发生：

- Voice 的 `providerId` 与 active TTS Provider 不一致。
- LLM Provider 已切换，但保留上一个 Provider 的 Model。
- UI 显示有选择，运行时实际不可用。

Provider-scoped map 可以恢复每个 Provider 的最后选择，并消除错配。

## 13. 数据迁移

迁移必须幂等，由独立 repository/controller 执行，不能散落在 Widget `initState`。

### TTS

1. 读取 `active_provider_id`。
2. 若新 Voice map 不存在，读取 legacy `active_voice_id`。
3. 查询 Voice；只有 `voice.providerId == activeProviderId` 时写入新 map。
4. 不匹配或 Voice 不存在时不迁移，readiness 进入 `setupRequired`。
5. 迁移期读取新 map 优先，找不到时才 fallback legacy key。

### LLM

1. 读取 `openai_compatible_dictionary_active_provider`。
2. 若新 Model map 不存在，将 `openai_compatible_dictionary_model` 写入 active Provider 对应条目。
3. 若 active Provider 不存在，不迁移 Model。
4. 新代码写入 map；过渡期镜像写 legacy global model，直到所有运行时消费者完成迁移。

### 迁移完成条件

- Library、Album、Generation 和 Dictionary Repository 不再直接读取 legacy selection key。
- 所有选择都通过 settings repository/controller。
- 至少经过一个兼容版本后才能删除 legacy fallback。

## 14. Readiness 规则

### TTS

`ready` 至少要求：

1. active Provider 存在。
2. `provider.validate()` 成功。
3. 本地 Provider 所需模型已安装。
4. 存在属于 active Provider 的选中 Voice。
5. 如果 Provider 支持可选 Model，已选择有效 Model。

### LLM

`ready` 至少要求：

1. active Provider Profile 存在。
2. Base URL 合法。
3. Provider-scoped API Key 存在。
4. 该 Provider 已选择 Model。
5. 最近测试失败时显示 `error`；允许用户保留配置并重试。

Readiness 计算结果必须是状态层唯一事实，Widget 不应重复拼装 `isMiniMax || isFishApi` 等 Provider 判断。

## 15. 共享 UI 组件

新增到 `presentation/widgets/design_system/`：

- `SettingsGroup`
- `SettingValueRow`
- `ServiceStatusCard`
- `ProviderOptionTile`
- `ReadinessBadge`
- `SettingsFeedbackBanner`
- `SettingsEmptyState`
- `SettingsErrorState`

现有 `AppSurface`、`AppSectionHeader`、Theme 和 tokens 继续作为底座。

组件职责：

- 统一高度、padding、divider、标题、subtitle、value 和 chevron。
- 统一 loading/disabled/error/selected 状态。
- 不读取业务 Provider；状态由 controller 转成 view data。

## 16. 导航规则

| 任务 | 容器 |
| --- | --- |
| Settings 根页 | Tab 内 pushed page |
| Service 页面 | 完整页面 |
| Provider Picker | 完整页面 |
| Provider Details / 编辑凭据 | 完整页面 |
| Model Picker | 完整页面 |
| Voice Picker / 管理 | 完整页面 |
| 确认删除 | Dialog |
| 单选短选项，如生成模式 | Bottom Sheet |
| 简短即时反馈 | Inline banner / SnackBar |

不再使用 PopupMenu 选择 TTS Provider，也不使用多字段 Bottom Sheet 编辑 LLM Provider。

## 17. 实施阶段

### Phase 0a：Legacy 行为测绘

- 当前相关自动化覆盖非常有限，不能假设现有 fallback 语义已经被测试固定。
- 新建 `docs/legacy_settings_matrix.md`，列出 `active_provider_id`、`active_voice_id`、`openai_compatible_dictionary_active_provider`、`openai_compatible_dictionary_model` 的全部读写位置。
- 对每个读写点记录调用场景、Provider 约束、空值行为、fallback 行为和可能错配。
- 通过代码和现有测试能确认的行为标为 `defined`；依赖偶然调用顺序或无法证明的行为标为 `undefined`。
- 不改 UI。

完成标准：legacy settings matrix 覆盖全部直接读写点；每条迁移输入都有 `defined` 或 `undefined` 结论。

当前状态：已完成，见 [Legacy Settings Behavior Matrix](legacy_settings_matrix.md)。

### Phase 0b：Characterization tests

- 只为 Phase 0a 中 `defined` 的行为补 characterization tests。
- 覆盖 TTS active Provider、compatible Voice、LLM active Provider 和全局 Model 的现存行为。
- 对 `undefined` 行为不伪造历史契约，在迁移规则中明确采用安全结果：不猜测、不跨 Provider fallback，进入 `setupRequired`。
- 为迁移前的典型错配数据建立 fixture，但断言目标是“识别错配”，不是冻结错误行为。

完成标准：所有 `defined` 迁移输入受测试保护；所有 `undefined` 输入都有明确的新行为和测试用例。

当前状态：已完成。legacy `defined` 行为、跨 Provider Voice、悬空 LLM Provider 和安全 `setupRequired` 行为均有测试覆盖。

### Phase 1：状态与迁移层

- 新增 Provider-scoped selection repository。
- 新增 TTS/LLM settings controller。
- 实现幂等迁移。
- 运行时消费者改为读取 repository，不直接读 setting key。

完成标准：切换 Provider 可以恢复各自 Voice/Model，旧用户配置不丢失。

当前状态：已完成。Provider-scoped repository、schema v1 幂等迁移、legacy 兼容镜像、独立 TTS/LLM controllers 及 Library、Album、Voice Library、Dictionary runtime consumers 均已迁移。

### Phase 2：共享 Settings 组件

- 开始前重新审计 `ui_design_system.md` 的已知偏离表，先清理会被新 Settings 组件直接复制的负债。
- 状态标签使用现有 `TextTheme.labelLarge (14/1.3/600)`；除非语义或尺寸不同，不新增重复的 `labelMedium`。
- Settings 组件必须使用现有 AppSurface、AppSectionHeader、ChipTheme、ButtonTheme 和 design tokens，不复制旧 Settings 私有 builder 的字面量样式。
- 实现 SettingsGroup、SettingValueRow、ServiceStatusCard、ReadinessBadge。
- 覆盖 dark/light、窄屏和 130% text scale widget tests。

完成标准：新页面不再复制私有 `_buildGeneralRow`、`_buildNavTile` 等 builder；新增组件无 page-local magic spacing、radius、font weight 或 literal status color。

当前状态：已完成。共享实现位于 `presentation/widgets/design_system/settings_components.dart`，并复用 AppSurface、TextTheme、ColorScheme 与 AppDesignTokens。

### Phase 3：Settings 根页

- 改为 General / AI Services / Playback / Storage / Support。
- TTS 与 Dictionary Explanation 只显示 active summary 和 readiness。
- Voice Library 移出根页；Audio Cache 归入 Storage。

完成标准：根页不再直接修改 Provider、Model 或 Voice。

当前状态：已完成。根页使用 General / AI Services / Playback / Storage / Support，只显示服务摘要和 readiness。

### Phase 4：TTS Service

- 新增 Text to Speech 页面、Provider Picker、Provider Details、Voice Picker。
- 迁移本地模型管理、API Key 和 Generation Profile。
- 统一 Provider readiness。

完成标准：旧 TTS PopupMenu 与内联 Provider group 删除。

当前状态：已完成。TTS Provider、详情、连接测试、本地模型、API Key、生成模式和 Voice Library 均进入完整 Service 流程；未通过测试的 Provider 无法激活。

### Phase 5：LLM Service

- 新增 Dictionary Explanation 页面。
- Provider 管理、凭据、测试和 Model 选择迁入统一模板。
- Model Picker 只加载当前 Provider。
- 将 `llm_provider_screen.dart` 的管理流程迁入 Provider Picker / Provider Details。
- 将 `llm_model_screen.dart` 的选择流程迁入当前 Provider 作用域内的 Model Picker。

完成标准：选择 Model 不再隐式切换 Provider；旧 `llm_provider_screen.dart`、`llm_model_screen.dart` 及其路由入口删除，所有 LLM 设置入口汇入 `DictionaryExplanationServiceScreen`。

当前状态：已完成。Model Picker 仅请求 active Provider，Model 选择只写该 Provider 的 map；两个旧页面及路由入口已删除。

迁移期间需要追踪的 legacy service API：

| API | 当前用途 | 目标状态 |
| --- | --- | --- |
| `configurations` | Provider 管理页直接读取列表 | 只允许 LLM controller/repository 调用 |
| `activeProvider` | Settings 与 Model 页读取当前 Provider | 只允许 LLM controller/repository 调用 |
| `model` | Settings 与 Model 页读取全局 Model | 迁移为 Provider-scoped map 后保留兼容读取，最终移除 |
| `fetchAllModels()` | 旧 Model 页跨 Provider 拉取 | 替换为当前 Provider scoped fetch |
| `selectModel(providerId, model)` | 同时切换 Provider 与 Model | UI 禁止直调；拆为显式 Provider 激活和 scoped Model 选择 |

Phase 5 结束时先消除旧页面对这些 API 的直接调用；API 本身是否删除由 Phase 6 根据运行时依赖决定。

### Phase 6：清理与视觉回归

- 删除 legacy widget、无用 setting 读取和重复样式。
- 补核心设置流程 golden tests。
- 更新 `ui_design_system.md` 的已知偏离表。

完成标准：全量 analyze/test/build 通过，旧设置迁移测试通过。

当前状态：已完成。Settings root 已有 dark 390 golden 和 light 430 / 130% text golden，并覆盖 390/430、dark/light、100%/130% 的无溢出 widget matrix；`flutter analyze`、全量测试和 macOS debug build 均通过。

## 18. 测试矩阵

### 状态与迁移测试

- legacy TTS Provider + compatible Voice 正确迁移。
- legacy Voice 属于其他 Provider 时不产生错误映射。
- legacy LLM active Provider + Model 正确迁移。
- 迁移重复执行结果不变。
- 删除 active LLM Provider 后安全回退。
- 每个 Provider 恢复自己的 Model/Voice。

### Controller 测试

- 未配置 Provider 不能直接激活。
- 测试失败不会覆盖 active 配置。
- 选择 Model 不切换 Provider。
- readiness 在 API Key、模型下载、Voice 变化后正确刷新。

### Widget 测试

- Settings 根页显示 active summary，不显示 Provider count。
- TTS/LLM Service 页面结构一致。
- Provider Picker 正确显示 active、ready 和 setup-required。
- 多字段配置使用完整页面，不出现 Bottom Sheet。
- 390/430 宽度、100%/130% text scale、dark/light 双主题无溢出。

### 集成流程

```text
首次配置 TTS → 测试 → 激活 → 选择 Voice → 生成音频
切换 TTS Provider → 配置 → 激活 → 切回并恢复旧 Voice
首次配置 LLM → 测试 → 激活 → 选择 Model → 查词
切换 LLM Provider → 恢复 Provider 对应 Model
```

## 19. 验收标准

- 用户从 Settings 根页最多两次点击可以看到当前 Service 的完整配置。
- 根页一眼可见 TTS 与 Dictionary Explanation 是否 ready。
- TTS 与 LLM 的 Provider、Setup、Test、Activate、Model 交互顺序一致。
- Provider 切换不产生 Model/Voice 错配。
- 未就绪 Provider 不会静默成为 active。
- Model 选择不会隐式切换 Provider。
- 所有错误状态给出明确下一步动作。
- 所有旧配置能够迁移或进入可解释的 setup-required 状态。
- 页面遵循 Lumina UI Design System，无新增 magic spacing、radius、font 或 literal color。

## 20. 风险与控制

| 风险 | 控制措施 |
| --- | --- |
| 状态重构影响音频生成 | 先迁移 repository，保持 legacy fallback，并补集成测试 |
| API Key 丢失 | 不迁移密钥内容，只迁移 Provider 选择；沿用 ApiKeyStore |
| 本地模型异步状态复杂 | readiness 监听现有 model manager stream |
| Provider 能力差异导致 UI if/else 膨胀 | 使用 setup adapter 和 view data，不在 Widget 判断具体 Provider id |
| 一次性改动过大 | 严格按 Phase 提交，每阶段可独立回滚 |
| 新旧页面同时存在导致状态不一致 | 所有页面先统一读取新 controller，再替换 UI |

## 21. 已确定的产品决策

以下决策在实现阶段默认不再重新讨论：

1. Settings 根页只做摘要与导航。
2. Provider Picker 和多字段 Provider Details 使用完整页面。
3. 配置成功不等于激活，激活是明确动作。
4. Model Picker 绑定当前 Provider，不隐式切换 Provider。
5. Model/Voice 按 Provider 保存并恢复。
6. TTS 与 LLM 共享交互契约和 UI 组件，不强行共享底层 Provider 接口。
7. 先重构状态层，再替换 UI。

任何偏离以上决策的实现应在 PR 中说明原因，并同步更新本文档。
