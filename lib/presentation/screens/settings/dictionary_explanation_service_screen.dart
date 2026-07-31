import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/service_settings_controllers.dart';
import '../../../data/dictionary/openai_compatible_explanation_provider.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/app_section_header.dart';
import '../../widgets/design_system/settings_components.dart';

class DictionaryExplanationServiceScreen extends ConsumerWidget {
  const DictionaryExplanationServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        data: (data) => ListView(
          padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
          children: [
            ServiceStatusCard(
              icon: Icons.auto_awesome_outlined,
              title: context.tr('当前 AI 服务', 'Current AI service'),
              provider: data.providerName ?? context.tr('未选择服务', 'No provider'),
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
                  value: data.providerName ?? context.tr('未选择', 'Not selected'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LlmProviderPickerScreen(),
                    ),
                  ),
                ),
                SettingValueRow(
                  rowKey: const ValueKey('llm-model-settings'),
                  icon: Icons.psychology_outlined,
                  title: context.tr('模型', 'Model'),
                  value: data.modelId ?? context.tr('未选择', 'Not selected'),
                  onTap: data.providerId == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LlmModelPickerScreen(),
                          ),
                        ),
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
        ),
      ),
    );
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

class LlmProviderPickerScreen extends ConsumerWidget {
  const LlmProviderPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(llmSettingsControllerProvider);
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return CollapsingPageScaffold(
      title: 'LLM Providers',
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: 'Add Provider',
          onPressed: () => _add(context),
          icon: const Icon(Icons.add),
        ),
      ],
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SettingsErrorState(
          error: error,
          onRetry: () => ref.invalidate(llmSettingsControllerProvider),
        ),
        data: (data) => data.providers.isEmpty
            ? SettingsEmptyState(
                icon: Icons.hub_outlined,
                message: context.tr('尚未添加服务', 'No providers yet'),
                actionLabel: context.tr('添加服务', 'Add provider'),
                onAction: () => _add(context),
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  inset,
                  design.spaceSm,
                  inset,
                  design.spaceXl,
                ),
                children: [
                  SettingsGroup(
                    children: [
                      for (final provider in data.providers)
                        ProviderOptionTile(
                          provider: provider,
                          onTap: () => _openDetails(context, data, provider.id),
                          onEdit: () =>
                              _openDetails(context, data, provider.id),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final kind = await showModalBottomSheet<LlmProviderKind>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in LlmProviderKind.values)
              ListTile(
                title: Text(kind.displayName),
                subtitle: Text(
                  kind == LlmProviderKind.custom
                      ? 'OpenAI-compatible API'
                      : kind.defaultBaseUrl,
                ),
                onTap: () => Navigator.of(context).pop(kind),
              ),
          ],
        ),
      ),
    );
    if (kind == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LlmProviderDetailsScreen(kind: kind)),
    );
  }

  Future<void> _openDetails(
    BuildContext context,
    LlmSettingsState state,
    String id,
  ) async {
    final provider = state.configurations.firstWhere((item) => item.id == id);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LlmProviderDetailsScreen(kind: provider.kind, provider: provider),
      ),
    );
  }
}

class LlmProviderDetailsScreen extends ConsumerStatefulWidget {
  final LlmProviderKind kind;
  final LlmProviderConfiguration? provider;

  const LlmProviderDetailsScreen({
    super.key,
    required this.kind,
    this.provider,
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

  bool get _editing => widget.provider != null;

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
      body: ListView(
        padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
        children: [
          if (_feedback != null) ...[
            SettingsFeedbackBanner(message: _feedback!),
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
          SizedBox(height: design.spaceXl),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
          if (_editing) ...[
            SizedBox(height: design.spaceMd),
            OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: const Icon(Icons.wifi_tethering_outlined),
              label: const Text('Test connection'),
            ),
            SizedBox(height: design.spaceMd),
            FilledButton(
              onPressed: activeId == widget.provider!.id || !_providerReady
                  ? null
                  : _activate,
              child: Text(
                activeId == widget.provider!.id
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
    );
  }

  Future<void> _save() async {
    final key = _apiKey.text.trim();
    if (!_editing && key.isEmpty) {
      setState(() => _feedback = 'API Key is required.');
      return;
    }
    if (_name.text.trim().isEmpty || _baseUrl.text.trim().isEmpty) {
      setState(() => _feedback = 'Provider name and Base URL are required.');
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(llmSettingsControllerProvider.notifier);
    try {
      if (_editing) {
        await controller.updateProvider(
          provider: LlmProviderConfiguration(
            id: widget.provider!.id,
            kind: widget.kind,
            displayName: _name.text.trim(),
            baseUrl: _baseUrl.text.trim(),
          ),
          apiKey: key.isEmpty ? null : key,
        );
      } else {
        await controller.addProvider(
          kind: widget.kind,
          apiKey: key,
          displayName: _name.text,
          baseUrl: _baseUrl.text,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) setState(() => _feedback = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    final provider = LlmProviderConfiguration(
      id: widget.provider!.id,
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
        .selectProvider(widget.provider!.id);
    if (mounted) Navigator.of(context).pop();
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
        .removeProvider(widget.provider!.id);
    if (mounted) Navigator.of(context).pop();
  }
}

class LlmModelPickerScreen extends ConsumerStatefulWidget {
  const LlmModelPickerScreen({super.key});

  @override
  ConsumerState<LlmModelPickerScreen> createState() =>
      _LlmModelPickerScreenState();
}

class _LlmModelPickerScreenState extends ConsumerState<LlmModelPickerScreen> {
  late Future<LlmProviderModels> _models;

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
          return ListView(
            padding: EdgeInsets.fromLTRB(
              inset,
              design.spaceSm,
              inset,
              design.spaceXl,
            ),
            children: [
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
                      trailing: selected == model.id
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () async {
                        await ref
                            .read(llmSettingsControllerProvider.notifier)
                            .selectModel(model.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
