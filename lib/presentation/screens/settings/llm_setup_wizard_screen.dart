import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/service_settings_controllers.dart';
import '../../../data/dictionary/openai_compatible_explanation_provider.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/app_section_header.dart';
import '../../widgets/design_system/provider_brand_icon.dart';
import '../../widgets/design_system/settings_components.dart';

class LlmSetupWizardScreen extends ConsumerStatefulWidget {
  const LlmSetupWizardScreen({super.key});

  @override
  ConsumerState<LlmSetupWizardScreen> createState() =>
      _LlmSetupWizardScreenState();
}

class _LlmSetupWizardScreenState extends ConsumerState<LlmSetupWizardScreen> {
  final _name = TextEditingController();
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  int _step = 0;
  bool _forward = true;
  bool _initializing = true;
  bool _busy = false;
  LlmProviderKind? _kind;
  LlmProviderConfiguration? _configuration;
  String? _modelId;
  String? _error;
  List<LlmModelOption> _models = const [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final settings = await ref.read(llmSettingsControllerProvider.future);
      if (settings.providerId != null) {
        final configuration = settings.configurations.firstWhere(
          (item) => item.id == settings.providerId,
        );
        _useConfiguration(configuration);
        _modelId = settings.modelId;
        await _loadModels(configuration);
        _step = 2;
      }
      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return CollapsingPageScaffold(
      title: context.tr('AI 设置', 'AI Setup'),
      showBackButton: true,
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    design.spaceSm,
                    inset,
                    design.spaceMd,
                  ),
                  child: SetupProgressHeader(
                    title: context.tr('AI 设置进度', 'AI setup progress'),
                    steps: [
                      'Provider',
                      context.tr('密钥', 'Key'),
                      context.tr('模型', 'Model'),
                    ],
                    currentStep: _step,
                  ),
                ),
                Expanded(
                  child: SetupStepTransition(
                    step: _step,
                    forward: _forward,
                    child: _buildStep(inset),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      design.spaceSm,
                      inset,
                      design.spaceMd,
                    ),
                    child: SetupNavigationBar(
                      previousLabel: context.tr('上一步', 'Previous'),
                      nextLabel: _step == 2
                          ? context.tr('完成', 'Finish')
                          : context.tr('下一步', 'Next'),
                      busy: _busy,
                      onPrevious: _previous,
                      onNext: _canContinue ? _next : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  bool get _canContinue => switch (_step) {
    0 => _kind != null,
    1 => _kind != null,
    2 => _modelId != null,
    _ => false,
  };

  Widget _buildStep(double inset) {
    final design = context.appDesign;
    return ListView(
      key: ValueKey('llm-wizard-step-$_step'),
      padding: EdgeInsets.fromLTRB(inset, 0, inset, design.spaceXl),
      children: [
        if (_error != null) ...[
          SettingsFeedbackBanner(message: _error!, error: true),
          SizedBox(height: design.spaceMd),
        ],
        switch (_step) {
          0 => _providerStep(),
          1 => _keyStep(),
          _ => _modelStep(),
        },
      ],
    );
  }

  Widget _providerStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSectionHeader(
        title: context.tr('选择 AI Provider', 'Choose an AI provider'),
      ),
      SettingsGroup(
        children: [
          for (final kind in LlmProviderKind.values)
            ListTile(
              key: ValueKey('wizard-llm-provider-${kind.value}'),
              leading: _providerLeading(kind),
              title: Text(kind.displayName),
              subtitle: Text(
                kind == LlmProviderKind.custom
                    ? 'OpenAI-compatible API'
                    : kind.defaultBaseUrl,
              ),
              trailing: _kind == kind
                  ? const Icon(Icons.radio_button_checked)
                  : const Icon(Icons.radio_button_off),
              selected: _kind == kind,
              onTap: () => setState(() {
                _selectKind(kind);
                _error = null;
              }),
            ),
        ],
      ),
    ],
  );

  Widget _providerLeading(LlmProviderKind kind) {
    final brand = providerBrandForLlmKind(kind.value);
    if (brand == null) return const Icon(Icons.hub_outlined);
    return ProviderBrandIcon(brand: brand, selected: _kind == kind);
  }

  Widget _keyStep() {
    final kind = _kind!;
    final uri = switch (kind) {
      LlmProviderKind.openAi => Uri.parse(
        'https://platform.openai.com/api-keys',
      ),
      LlmProviderKind.deepSeek => Uri.parse(
        'https://platform.deepseek.com/api_keys',
      ),
      LlmProviderKind.zai => Uri.parse(
        'https://z.ai/manage-apikey/apikey-list',
      ),
      LlmProviderKind.custom => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: context.tr(
            '连接 ${kind.displayName}',
            'Connect ${kind.displayName}',
          ),
        ),
        SettingsFeedbackBanner(
          message: context.tr(
            '获取 API Key，粘贴并验证连接。成功后将在当前页面继续选择模型。',
            'Get an API key, paste it below, and verify the connection. Model selection continues on this page.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Provider name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _baseUrl,
          decoration: const InputDecoration(labelText: 'Base URL'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('wizard-llm-api-key'),
          controller: _apiKey,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'API Key',
            helperText: _configuration == null
                ? context.tr('必填', 'Required')
                : context.tr('留空可使用已保存的密钥', 'Leave empty to use the saved key'),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('在哪里获取 API Key？', 'Where do I get an API key?'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  kind == LlmProviderKind.custom
                      ? context.tr(
                          '请在服务商控制台创建 API Key，并确认 Base URL 支持 /models 和 /chat/completions。',
                          'Create an API key in the provider console and confirm the Base URL supports /models and /chat/completions.',
                        )
                      : context.tr(
                          '1. 登录 ${kind.displayName} 控制台\n'
                              '2. 打开 API Keys 并创建密钥\n'
                              '3. 复制密钥并粘贴到上方',
                          '1. Sign in to the ${kind.displayName} console\n'
                              '2. Open API Keys and create a key\n'
                              '3. Copy the key and paste it above',
                        ),
                ),
                if (uri != null)
                  TextButton.icon(
                    key: ValueKey('get-llm-api-key-${kind.value}'),
                    onPressed: () => _openUrl(uri),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      context.tr(
                        '打开 ${kind.displayName} API Keys',
                        'Open ${kind.displayName} API Keys',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _modelStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSectionHeader(title: context.tr('选择 AI 模型', 'Choose an AI model')),
      if (_models.isEmpty)
        SettingsEmptyState(
          icon: Icons.psychology_outlined,
          message: context.tr('没有找到可用模型', 'No models are available'),
          actionLabel: context.tr('重新同步', 'Sync again'),
          onAction: _reloadModels,
        )
      else
        SettingsGroup(
          children: [
            for (final model in _models)
              ListTile(
                key: ValueKey('wizard-llm-model-${model.id}'),
                title: Text(model.id),
                subtitle: model.ownedBy == null ? null : Text(model.ownedBy!),
                trailing: _modelId == model.id
                    ? const Icon(Icons.radio_button_checked)
                    : const Icon(Icons.radio_button_off),
                selected: _modelId == model.id,
                onTap: () => setState(() {
                  _modelId = model.id;
                  _error = null;
                }),
              ),
          ],
        ),
    ],
  );

  void _selectKind(LlmProviderKind kind) {
    _kind = kind;
    _configuration = null;
    final data = ref.read(llmSettingsControllerProvider).asData?.value;
    if (data != null) {
      for (final configuration in data.configurations) {
        if (configuration.kind == kind) {
          _useConfiguration(configuration);
          return;
        }
      }
    }
    _name.text = kind.displayName;
    _baseUrl.text = kind.defaultBaseUrl;
    _apiKey.clear();
    _modelId = null;
    _models = const [];
  }

  void _useConfiguration(LlmProviderConfiguration configuration) {
    _configuration = configuration;
    _kind = configuration.kind;
    _name.text = configuration.displayName;
    _baseUrl.text = configuration.baseUrl;
    _apiKey.clear();
  }

  void _previous() {
    if (_busy) return;
    if (_step == 0) {
      Navigator.of(context).pop(false);
      return;
    }
    _goTo(_step - 1);
  }

  Future<void> _next() async {
    switch (_step) {
      case 0:
        _goTo(1);
      case 1:
        await _connectProvider();
      case 2:
        await _finish();
    }
  }

  void _goTo(int step) {
    setState(() {
      _forward = step > _step;
      _step = step;
      _error = null;
    });
  }

  Future<void> _connectProvider() async {
    final kind = _kind!;
    final name = _name.text.trim();
    final baseUrl = _baseUrl.text.trim();
    final key = _apiKey.text.trim();
    if (name.isEmpty ||
        baseUrl.isEmpty ||
        (_configuration == null && key.isEmpty)) {
      setState(() {
        _error = context.tr(
          '请填写 Provider 名称、Base URL 和 API Key。',
          'Enter the provider name, Base URL, and API key.',
        );
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(llmSettingsControllerProvider.notifier);
      final existing = _configuration;
      if (existing == null) {
        _configuration = await notifier.addProvider(
          kind: kind,
          apiKey: key,
          displayName: name,
          baseUrl: baseUrl,
        );
      } else {
        final updated = LlmProviderConfiguration(
          id: existing.id,
          kind: kind,
          displayName: name,
          baseUrl: baseUrl,
        );
        await notifier.updateProvider(
          provider: updated,
          apiKey: key.isEmpty ? null : key,
        );
        _configuration = updated;
      }
      ref.invalidate(llmSettingsControllerProvider);
      await ref.read(llmSettingsControllerProvider.future);
      await ref
          .read(llmSettingsControllerProvider.notifier)
          .selectProvider(_configuration!.id);
      await _loadModels(_configuration!);
      if (mounted) _goTo(2);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = context.tr(
            '连接失败，请检查 API Key、Base URL 和网络：$error',
            'Connection failed. Check the API key, Base URL, and network: $error',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(llmSettingsControllerProvider.notifier)
          .selectModel(_modelId!);
      await ref.read(llmSettingsControllerProvider.future);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadModels(LlmProviderConfiguration configuration) async {
    final group = await ref
        .read(openAiCompatibleExplanationProvider)
        .fetchModels(configuration);
    if (group.failed) throw group.error!;
    _models = group.models;
    if (_modelId != null && !group.models.any((item) => item.id == _modelId)) {
      _modelId = null;
    }
  }

  Future<void> _reloadModels() async {
    final configuration = _configuration;
    if (configuration == null) return;
    setState(() => _busy = true);
    try {
      await _loadModels(configuration);
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openUrl(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(uri.toString())));
  }
}
