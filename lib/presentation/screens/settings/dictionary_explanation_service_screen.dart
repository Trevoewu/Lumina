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
import 'llm_setup_wizard_screen.dart';

class DictionaryExplanationServiceScreen extends ConsumerStatefulWidget {
  final bool returnWhenReady;

  const DictionaryExplanationServiceScreen({
    super.key,
    this.returnWhenReady = false,
  });

  @override
  ConsumerState<DictionaryExplanationServiceScreen> createState() =>
      _DictionaryExplanationServiceScreenState();
}

class _DictionaryExplanationServiceScreenState
    extends ConsumerState<DictionaryExplanationServiceScreen> {
  bool _setupAutoStarted = false;
  bool _setupFlowOpen = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(llmSettingsControllerProvider);
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return CollapsingPageScaffold(
      title: context.tr('AI 模型', 'AI Model'),
      showBackButton: true,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SettingsErrorState(
          error: error,
          onRetry: () => ref.invalidate(llmSettingsControllerProvider),
        ),
        data: (data) {
          if (data.readiness != ServiceReadiness.ready) {
            if (!_setupAutoStarted) {
              _setupAutoStarted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _resumeSetup(data);
              });
            }
            return _buildSetupLanding(context, data, inset: inset);
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
            children: [
              ServiceStatusCard(
                icon: Icons.auto_awesome_outlined,
                title: context.tr('当前 AI 服务', 'Current AI service'),
                provider:
                    data.providerName ?? context.tr('未选择服务', 'No provider'),
                selection: data.modelId ?? context.tr('未选择模型', 'No model'),
                readiness: data.readiness,
                onTap: () {},
              ),
              if (data.notice != null) ...[
                SizedBox(height: design.spaceMd),
                SettingsFeedbackBanner(message: data.notice!.message),
              ],
              AppSectionHeader(title: context.tr('配置', 'Configuration')),
              SettingsGroup(
                children: [
                  SettingValueRow(
                    icon: Icons.hub_outlined,
                    title: 'Provider',
                    subtitle: context.tr(
                      '选择服务后继续设置 API Key',
                      'Continue to API key setup after choosing',
                    ),
                    value:
                        data.providerName ?? context.tr('未选择', 'Not selected'),
                    onTap: () => _openProviders(
                      context,
                      ref,
                      guidedSetup: data.readiness != ServiceReadiness.ready,
                    ),
                  ),
                  SettingValueRow(
                    rowKey: const ValueKey('llm-model-settings'),
                    icon: Icons.psychology_outlined,
                    title: context.tr('模型', 'Model'),
                    subtitle: data.providerId == null
                        ? context.tr(
                            '请先完成 Provider 和 API Key 设置',
                            'Set up a provider and API key first',
                          )
                        : context.tr(
                            '同步供应商模型并选择',
                            'Sync provider models and choose one',
                          ),
                    value: data.modelId ?? context.tr('未选择', 'Not selected'),
                    onTap: data.providerId == null
                        ? null
                        : () =>
                              _openModels(context, ref, guidedSelection: false),
                  ),
                  if (data.providerId != null)
                    SettingValueRow(
                      icon: Icons.wifi_tethering_outlined,
                      title: context.tr('测试连接', 'Test connection'),
                      onTap: () => _test(context, ref),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSetupLanding(
    BuildContext context,
    LlmSettingsState data, {
    required double inset,
  }) {
    final design = context.appDesign;
    final providerConnected = data.providerId != null;
    return ListView(
      padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
      children: [
        SetupProgressHeader(
          title: context.tr('AI 设置进度', 'AI setup progress'),
          steps: [
            'Provider',
            context.tr('密钥', 'Key'),
            context.tr('模型', 'Model'),
          ],
          currentStep: providerConnected ? 2 : 0,
        ),
        SizedBox(height: design.spaceMd),
        if (data.notice != null) ...[
          SettingsFeedbackBanner(message: data.notice!.message),
          SizedBox(height: design.spaceMd),
        ],
        SetupActionCard(
          icon: providerConnected
              ? Icons.psychology_outlined
              : Icons.hub_outlined,
          title: providerConnected
              ? context.tr('选择 AI 模型', 'Choose an AI model')
              : context.tr('选择 AI Provider', 'Choose an AI provider'),
          description: providerConnected
              ? context.tr(
                  '${data.providerName ?? 'Provider'} 已连接。同步可用模型并选择 AI 功能使用的模型。',
                  '${data.providerName ?? 'Provider'} is connected. Sync available models and choose one for AI features.',
                )
              : context.tr(
                  '选择 Provider，获取并设置 API Key。验证成功后会自动继续选择模型。',
                  'Choose a provider, get and set its API key. After verification, setup continues to model selection.',
                ),
          actionLabel: context.tr('继续设置', 'Continue setup'),
          actionKey: const ValueKey('continue-llm-setup'),
          onPressed: () => _resumeSetup(data),
        ),
      ],
    );
  }

  Future<void> _resumeSetup(LlmSettingsState data) async {
    if (_setupFlowOpen || !mounted) return;
    _setupFlowOpen = true;
    try {
      final selected = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LlmSetupWizardScreen()),
      );
      if (selected != true || !mounted) return;
      ref.invalidate(llmSettingsControllerProvider);
      final refreshed = await ref.read(llmSettingsControllerProvider.future);
      if (mounted &&
          widget.returnWhenReady &&
          refreshed.readiness == ServiceReadiness.ready) {
        Navigator.of(context).pop(true);
      }
    } finally {
      _setupFlowOpen = false;
    }
  }

  Future<void> _openProviders(
    BuildContext context,
    WidgetRef ref, {
    required bool guidedSetup,
  }) async {
    final ready = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LlmProviderPickerScreen(guidedSetup: guidedSetup),
      ),
    );
    ref.invalidate(llmSettingsControllerProvider);
    if (ready == true && widget.returnWhenReady && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<bool?> _openModels(
    BuildContext context,
    WidgetRef ref, {
    required bool guidedSelection,
  }) async {
    final selected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LlmModelPickerScreen(guidedSelection: guidedSelection),
      ),
    );
    ref.invalidate(llmSettingsControllerProvider);
    if (selected == true && widget.returnWhenReady && context.mounted) {
      Navigator.of(context).pop(true);
    }
    return selected;
  }

  Future<void> _test(BuildContext context, WidgetRef ref) async {
    final valid = await ref
        .read(llmSettingsControllerProvider.notifier)
        .testProvider();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(valid ? 'Connection succeeded.' : 'Connection failed.'),
      ),
    );
  }
}

class LlmProviderPickerScreen extends ConsumerStatefulWidget {
  final bool guidedSetup;

  const LlmProviderPickerScreen({super.key, this.guidedSetup = false});

  @override
  ConsumerState<LlmProviderPickerScreen> createState() =>
      _LlmProviderPickerScreenState();
}

class _LlmProviderPickerScreenState
    extends ConsumerState<LlmProviderPickerScreen> {
  String? _switchingProviderId;
  String? _feedback;
  LlmProviderKind? _selectedKind;
  bool _addingInline = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(llmSettingsControllerProvider);
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return CollapsingPageScaffold(
      title: 'LLM Providers',
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: 'Add Provider',
          onPressed: () => setState(() => _addingInline = true),
          icon: const Icon(Icons.add),
        ),
      ],
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SettingsErrorState(
          error: error,
          onRetry: () => ref.invalidate(llmSettingsControllerProvider),
        ),
        data: (data) {
          if (widget.guidedSetup || _addingInline) {
            return _buildProviderChoice(data, inset: inset);
          }
          return data.providers.isEmpty
              ? SettingsEmptyState(
                  icon: Icons.hub_outlined,
                  message: context.tr('尚未添加服务', 'No providers yet'),
                  actionLabel: context.tr('添加服务', 'Add provider'),
                  onAction: () => setState(() => _addingInline = true),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    design.spaceSm,
                    inset,
                    design.spaceXl,
                  ),
                  children: [
                    if (_feedback != null) ...[
                      SettingsFeedbackBanner(message: _feedback!, error: true),
                      SizedBox(height: design.spaceMd),
                    ],
                    SettingsGroup(
                      children: [
                        for (final provider in data.providers)
                          ProviderOptionTile(
                            provider: provider,
                            leading: _providerLeading(
                              data,
                              provider.id,
                              selected: provider.active,
                            ),
                            onTap:
                                provider.readiness == ServiceReadiness.error ||
                                    provider.active
                                ? () => _openDetails(
                                    data,
                                    provider.id,
                                    guidedSetup:
                                        provider.readiness ==
                                        ServiceReadiness.error,
                                  )
                                : () => _useProvider(provider.id),
                            onEdit: () => _openDetails(data, provider.id),
                          ),
                      ],
                    ),
                  ],
                );
        },
      ),
    );
  }

  SetupProgressHeader _progress(BuildContext context) => SetupProgressHeader(
    title: context.tr('AI 设置进度', 'AI setup progress'),
    steps: ['Provider', context.tr('密钥', 'Key'), context.tr('模型', 'Model')],
    currentStep: 0,
  );

  Widget? _providerLeading(
    LlmSettingsState data,
    String providerId, {
    required bool selected,
  }) {
    for (final configuration in data.configurations) {
      if (configuration.id != providerId) continue;
      final brand = providerBrandForLlmKind(configuration.kind.value);
      if (brand != null) {
        return ProviderBrandIcon(brand: brand, selected: selected);
      }
      break;
    }
    return null;
  }

  Widget _kindLeading(LlmProviderKind kind) {
    final brand = providerBrandForLlmKind(kind.value);
    if (brand == null) return const Icon(Icons.hub_outlined);
    return ProviderBrandIcon(brand: brand, selected: _selectedKind == kind);
  }

  Widget _buildProviderChoice(LlmSettingsState data, {required double inset}) {
    final design = context.appDesign;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              inset,
              design.spaceMd,
              inset,
              design.spaceXl,
            ),
            children: [
              if (widget.guidedSetup) ...[
                _progress(context),
                SizedBox(height: design.spaceMd),
              ],
              AppSectionHeader(
                title: context.tr('选择 AI Provider', 'Choose an AI provider'),
              ),
              SettingsGroup(
                children: [
                  for (final kind in LlmProviderKind.values)
                    ListTile(
                      key: ValueKey('choose-llm-provider-${kind.value}'),
                      leading: _kindLeading(kind),
                      title: Text(kind.displayName),
                      subtitle: Text(
                        kind == LlmProviderKind.custom
                            ? 'OpenAI-compatible API'
                            : kind.defaultBaseUrl,
                      ),
                      trailing: Icon(
                        _selectedKind == kind
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      selected: _selectedKind == kind,
                      onTap: () => setState(() => _selectedKind = kind),
                    ),
                ],
              ),
            ],
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
              nextLabel: context.tr('下一步', 'Next'),
              onPrevious: () {
                if (widget.guidedSetup) {
                  Navigator.of(context).maybePop();
                } else {
                  setState(() {
                    _addingInline = false;
                    _selectedKind = null;
                  });
                }
              },
              onNext: _selectedKind == null
                  ? null
                  : () => _continueProviderChoice(data, _selectedKind!),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _continueProviderChoice(
    LlmSettingsState data,
    LlmProviderKind kind,
  ) async {
    LlmProviderConfiguration? existing;
    for (final provider in data.configurations) {
      if (provider.kind == kind) {
        existing = provider;
        break;
      }
    }
    if (existing != null) {
      final option = data.providers.firstWhere(
        (item) => item.id == existing!.id,
      );
      if (option.readiness == ServiceReadiness.error) {
        await _openDetails(data, existing.id, guidedSetup: true);
      } else {
        await _useProvider(existing.id);
      }
      return;
    }
    if (!mounted) return;
    final ready = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LlmProviderDetailsScreen(kind: kind, guidedSetup: true),
      ),
    );
    ref.invalidate(llmSettingsControllerProvider);
    if (ready == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _openDetails(
    LlmSettingsState state,
    String id, {
    bool guidedSetup = false,
  }) async {
    final provider = state.configurations.firstWhere((item) => item.id == id);
    final ready = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LlmProviderDetailsScreen(
          kind: provider.kind,
          provider: provider,
          guidedSetup: guidedSetup,
        ),
      ),
    );
    ref.invalidate(llmSettingsControllerProvider);
    if (ready == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _useProvider(String providerId) async {
    if (_switchingProviderId != null) return;
    setState(() {
      _switchingProviderId = providerId;
      _feedback = null;
    });
    try {
      await ref
          .read(llmSettingsControllerProvider.notifier)
          .selectProvider(providerId);
      await ref.read(llmSettingsControllerProvider.future);
      final selectedModel = await ref
          .read(providerSelectionRepositoryProvider)
          .selectedLlmModel(providerId);
      if (selectedModel == null && mounted) {
        final selected = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const LlmModelPickerScreen(guidedSelection: true),
          ),
        );
        if (selected != true) {
          if (!mounted) return;
          setState(() {
            _switchingProviderId = null;
            _feedback = context.tr(
              'Provider 已连接，请选择模型完成设置。',
              'The provider is connected. Choose a model to finish setup.',
            );
          });
          return;
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _switchingProviderId = null;
        _feedback = context.tr(
          '无法使用此 Provider，请检查 API Key 和网络：$error',
          'Could not use this provider. Check its API key and connection: $error',
        );
      });
    }
  }
}

class LlmProviderDetailsScreen extends ConsumerStatefulWidget {
  final LlmProviderKind kind;
  final LlmProviderConfiguration? provider;
  final bool guidedSetup;

  const LlmProviderDetailsScreen({
    super.key,
    required this.kind,
    this.provider,
    this.guidedSetup = false,
  });

  @override
  ConsumerState<LlmProviderDetailsScreen> createState() =>
      _LlmProviderDetailsScreenState();
}

class _LlmProviderDetailsScreenState
    extends ConsumerState<LlmProviderDetailsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  final _apiKey = TextEditingController();
  bool _saving = false;
  bool _testing = false;
  bool _providerReady = false;
  String? _feedback;
  bool _feedbackIsError = false;
  LlmProviderConfiguration? _createdProvider;

  bool get _editing => _currentProvider != null;
  LlmProviderConfiguration? get _currentProvider =>
      widget.provider ?? _createdProvider;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.provider?.displayName ?? widget.kind.displayName,
    );
    _baseUrl = TextEditingController(
      text: widget.provider?.baseUrl ?? widget.kind.defaultBaseUrl,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final activeId = ref
        .watch(llmSettingsControllerProvider)
        .asData
        ?.value
        .providerId;
    return CollapsingPageScaffold(
      title: _editing ? 'Edit Provider' : 'Add Provider',
      showBackButton: true,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                inset,
                design.spaceSm,
                inset,
                design.spaceXl,
              ),
              children: [
                if (widget.guidedSetup) ...[
                  SetupProgressHeader(
                    title: context.tr('AI 设置进度', 'AI setup progress'),
                    steps: [
                      'Provider',
                      context.tr('密钥', 'Key'),
                      context.tr('模型', 'Model'),
                    ],
                    currentStep: 1,
                  ),
                  SizedBox(height: design.spaceMd),
                  SettingsFeedbackBanner(
                    message: context.tr(
                      '先获取 API Key，粘贴并验证连接。成功后会自动同步模型。',
                      'Get an API key, paste it below, and verify the connection. Models will sync next.',
                    ),
                  ),
                  SizedBox(height: design.spaceMd),
                ],
                if (_feedback != null) ...[
                  SettingsFeedbackBanner(
                    message: _feedback!,
                    error: _feedbackIsError,
                  ),
                  SizedBox(height: design.spaceMd),
                ],
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Provider name'),
                ),
                SizedBox(height: design.spaceMd),
                TextField(
                  controller: _baseUrl,
                  decoration: const InputDecoration(labelText: 'Base URL'),
                ),
                SizedBox(height: design.spaceMd),
                TextField(
                  key: const ValueKey('llm-api-key-field'),
                  controller: _apiKey,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    helperText: _editing
                        ? 'Leave empty to keep the saved key.'
                        : 'Required',
                  ),
                ),
                SizedBox(height: design.spaceMd),
                _buildApiKeyGuide(),
                SizedBox(height: design.spaceXl),
                if (!widget.guidedSetup)
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(context.tr('保存', 'Save')),
                  ),
                if (_editing && !widget.guidedSetup) ...[
                  SizedBox(height: design.spaceMd),
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: const Icon(Icons.wifi_tethering_outlined),
                    label: const Text('Test connection'),
                  ),
                  SizedBox(height: design.spaceMd),
                  FilledButton(
                    onPressed:
                        activeId == _currentProvider!.id || !_providerReady
                        ? null
                        : _activate,
                    child: Text(
                      activeId == _currentProvider!.id
                          ? 'Current provider'
                          : 'Use provider',
                    ),
                  ),
                  SizedBox(height: design.spaceXl),
                  TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete provider'),
                  ),
                ],
              ],
            ),
          ),
          if (widget.guidedSetup)
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
                  nextLabel: context.tr('下一步', 'Next'),
                  busy: _saving,
                  onPrevious: () => Navigator.of(context).pop(false),
                  onNext: _save,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final key = _apiKey.text.trim();
    if (!_editing && key.isEmpty) {
      setState(() {
        _feedback = 'API Key is required.';
        _feedbackIsError = true;
      });
      return;
    }
    if (_name.text.trim().isEmpty || _baseUrl.text.trim().isEmpty) {
      setState(() {
        _feedback = 'Provider name and Base URL are required.';
        _feedbackIsError = true;
      });
      return;
    }
    setState(() {
      _saving = true;
      _feedback = null;
      _feedbackIsError = false;
    });
    try {
      if (_editing) {
        await ref
            .read(llmSettingsControllerProvider.notifier)
            .updateProvider(
              provider: LlmProviderConfiguration(
                id: _currentProvider!.id,
                kind: widget.kind,
                displayName: _name.text.trim(),
                baseUrl: _baseUrl.text.trim(),
              ),
              apiKey: key.isEmpty ? null : key,
            );
      } else {
        _createdProvider = await ref
            .read(llmSettingsControllerProvider.notifier)
            .addProvider(
              kind: widget.kind,
              apiKey: key,
              displayName: _name.text,
              baseUrl: _baseUrl.text,
            );
      }

      if (!widget.guidedSetup) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      ref.invalidate(llmSettingsControllerProvider);
      await ref.read(llmSettingsControllerProvider.future);
      final provider = _currentProvider!;
      await ref
          .read(llmSettingsControllerProvider.notifier)
          .selectProvider(provider.id);
      await ref.read(llmSettingsControllerProvider.future);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _feedback = context.tr(
          '连接成功，正在同步可用模型。',
          'Connected. Available models are syncing.',
        );
      });
      final selected = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const LlmModelPickerScreen(guidedSelection: true),
        ),
      );
      if (!mounted) return;
      if (selected == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _feedback = context.tr(
            'Provider 已连接，请选择一个模型完成设置。',
            'The provider is connected. Choose a model to finish setup.',
          );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _feedback = context.tr(
            '连接失败，请检查 API Key、Base URL 和网络：$error',
            'Connection failed. Check the API key, Base URL, and network: $error',
          );
          _feedbackIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    final current = _currentProvider!;
    final provider = LlmProviderConfiguration(
      id: current.id,
      kind: widget.kind,
      displayName: _name.text.trim(),
      baseUrl: _baseUrl.text.trim(),
    );
    if (_apiKey.text.trim().isNotEmpty) {
      await ref
          .read(llmSettingsControllerProvider.notifier)
          .updateProvider(provider: provider, apiKey: _apiKey.text);
    }
    final valid = await ref
        .read(openAiCompatibleExplanationProvider)
        .validateProvider(provider);
    if (mounted) {
      setState(() {
        _testing = false;
        _providerReady = valid;
        _feedback = valid ? 'Connection succeeded.' : 'Connection failed.';
      });
    }
  }

  Future<void> _activate() async {
    await ref
        .read(llmSettingsControllerProvider.notifier)
        .selectProvider(_currentProvider!.id);
    await ref.read(llmSettingsControllerProvider.future);
    final modelId = await ref
        .read(providerSelectionRepositoryProvider)
        .selectedLlmModel(_currentProvider!.id);
    if (modelId == null && mounted) {
      final selected = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const LlmModelPickerScreen(guidedSelection: true),
        ),
      );
      if (selected != true) return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete provider?'),
        content: const Text('The saved API key will also be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(llmSettingsControllerProvider.notifier)
        .removeProvider(_currentProvider!.id);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildApiKeyGuide() {
    final uri = switch (widget.kind) {
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
    final design = context.appDesign;
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(design.radiusSmall),
      ),
      child: Padding(
        padding: EdgeInsets.all(design.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.key_outlined, size: 20, color: colors.primary),
                SizedBox(width: design.spaceSm),
                Expanded(
                  child: Text(
                    context.tr('在哪里获取 API Key？', 'Where do I get an API key?'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            SizedBox(height: design.spaceSm),
            Text(
              widget.kind == LlmProviderKind.custom
                  ? context.tr(
                      '请前往该 OpenAI-compatible 服务商的控制台创建 API Key，'
                          '并确认 Base URL 支持 /models 与 /chat/completions。',
                      'Create an API key in your OpenAI-compatible provider console and confirm '
                          'that the Base URL supports /models and /chat/completions.',
                    )
                  : context.tr(
                      '1. 登录 ${widget.kind.displayName} 控制台\n'
                          '2. 打开 API Keys 页面并创建密钥\n'
                          '3. 复制密钥并粘贴到上方',
                      '1. Sign in to the ${widget.kind.displayName} console\n'
                          '2. Open API Keys and create a key\n'
                          '3. Copy the key and paste it above',
                    ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (uri != null) ...[
              SizedBox(height: design.spaceSm),
              TextButton.icon(
                key: ValueKey('get-llm-api-key-${widget.kind.value}'),
                onPressed: () => _openApiKeyPage(uri),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  context.tr(
                    '打开 ${widget.kind.displayName} API Keys',
                    'Open ${widget.kind.displayName} API Keys',
                  ),
                ),
              ),
            ],
            Text(
              context.tr(
                '密钥只保存在此设备上。云服务可能产生费用。',
                'The key stays on this device. Cloud usage may incur charges.',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openApiKeyPage(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Show a copyable fallback below.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            '无法打开网页，请在浏览器中访问：$uri',
            'Could not open the page. Visit this address in a browser: $uri',
          ),
        ),
      ),
    );
  }
}

class LlmModelPickerScreen extends ConsumerStatefulWidget {
  final bool guidedSelection;

  const LlmModelPickerScreen({super.key, this.guidedSelection = false});

  @override
  ConsumerState<LlmModelPickerScreen> createState() =>
      _LlmModelPickerScreenState();
}

class _LlmModelPickerScreenState extends ConsumerState<LlmModelPickerScreen> {
  late Future<LlmProviderModels> _models;
  String? _pendingModelId;

  @override
  void initState() {
    super.initState();
    _models = _load();
  }

  Future<LlmProviderModels> _load() async {
    final state = await ref.read(llmSettingsControllerProvider.future);
    final provider = state.configurations.firstWhere(
      (item) => item.id == state.providerId,
    );
    return ref.read(openAiCompatibleExplanationProvider).fetchModels(provider);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref
        .watch(llmSettingsControllerProvider)
        .asData
        ?.value
        .modelId;
    final displayedSelection = _pendingModelId ?? selected;
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return CollapsingPageScaffold(
      title: context.tr('模型', 'Model'),
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: 'Refresh Models',
          onPressed: () => setState(() => _models = _load()),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: FutureBuilder<LlmProviderModels>(
        future: _models,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return SettingsErrorState(
                error: snapshot.error!,
                onRetry: () => setState(() => _models = _load()),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          final group = snapshot.data!;
          if (group.failed) {
            return SettingsErrorState(
              error: group.error!,
              onRetry: () => setState(() => _models = _load()),
            );
          }
          final modelList = ListView(
            padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 0),
            children: [
              if (widget.guidedSelection) ...[
                SetupProgressHeader(
                  title: context.tr('AI 设置进度', 'AI setup progress'),
                  steps: [
                    'Provider',
                    context.tr('密钥', 'Key'),
                    context.tr('模型', 'Model'),
                  ],
                  currentStep: 2,
                ),
                SizedBox(height: design.spaceMd),
                SettingsFeedbackBanner(
                  message: context.tr(
                    '已连接 ${group.provider.displayName}。请选择要用于 AI 功能的模型。',
                    '${group.provider.displayName} is connected. Choose the model to use for AI features.',
                  ),
                ),
                SizedBox(height: design.spaceMd),
              ],
              SettingsGroup(
                children: [
                  for (final model in group.models)
                    ListTile(
                      key: ValueKey(
                        'llm-model-${group.provider.id}-${model.id}',
                      ),
                      title: Text(model.id),
                      subtitle: model.ownedBy == null
                          ? null
                          : Text(model.ownedBy!),
                      trailing: displayedSelection == model.id
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () async {
                        if (widget.guidedSelection) {
                          setState(() => _pendingModelId = model.id);
                          return;
                        }
                        await ref
                            .read(llmSettingsControllerProvider.notifier)
                            .selectModel(model.id);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                ],
              ),
              SizedBox(height: design.spaceXl),
            ],
          );
          if (!widget.guidedSelection) return modelList;
          return Column(
            children: [
              Expanded(child: modelList),
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
                    nextLabel: context.tr('完成', 'Finish'),
                    onPrevious: () => Navigator.of(context).pop(false),
                    onNext: displayedSelection == null
                        ? null
                        : () async {
                            await ref
                                .read(llmSettingsControllerProvider.notifier)
                                .selectModel(displayedSelection);
                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
