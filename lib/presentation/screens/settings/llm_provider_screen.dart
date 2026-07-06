import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/dictionary/openai_compatible_explanation_provider.dart';
import '../../widgets/collapsing_page_scaffold.dart';

class LlmProviderScreen extends ConsumerStatefulWidget {
  const LlmProviderScreen({super.key});

  @override
  ConsumerState<LlmProviderScreen> createState() => _LlmProviderScreenState();
}

class _LlmProviderScreenState extends ConsumerState<LlmProviderScreen> {
  late Future<List<LlmProviderConfiguration>> _providersFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _providersFuture = ref
        .read(openAiCompatibleExplanationProvider)
        .configurations;
  }

  @override
  Widget build(BuildContext context) {
    return CollapsingPageScaffold(
      title: context.tr('大模型服务', 'LLM Providers'),
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: context.tr('添加服务', 'Add Provider'),
          icon: const Icon(Icons.add),
          onPressed: _chooseProviderKind,
        ),
      ],
      body: FutureBuilder<List<LlmProviderConfiguration>>(
        future: _providersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error!, onRetry: _refresh);
          }
          final providers = snapshot.data ?? const [];
          if (providers.isEmpty) {
            return _EmptyProviders(onAdd: _chooseProviderKind);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: providers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final provider = providers[index];
              return Material(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: ValueKey('llm-provider-${provider.id}'),
                  minTileHeight: 76,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: _ProviderIcon(kind: provider.kind),
                  title: Text(
                    provider.displayName,
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    provider.baseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.appTextSecondary,
                  ),
                  onTap: () => _editProvider(provider),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _providersFuture;
  }

  Future<void> _chooseProviderKind() async {
    final kind = await showModalBottomSheet<LlmProviderKind>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.appSurface,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  context.tr('添加大模型服务', 'Add LLM Provider'),
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final item in LlmProviderKind.values)
                ListTile(
                  leading: _ProviderIcon(kind: item),
                  title: Text(item.displayName),
                  subtitle: item == LlmProviderKind.custom
                      ? Text(
                          context.tr(
                            '其他 OpenAI 兼容接口',
                            'Another OpenAI-compatible API',
                          ),
                        )
                      : Text(item.defaultBaseUrl),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pop(item),
                ),
            ],
          ),
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final added = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      builder: (_) => _LlmProviderDetailsSheet(kind: kind),
    );
    if (added == true && mounted) setState(_reload);
  }

  Future<void> _editProvider(LlmProviderConfiguration provider) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      builder: (_) =>
          _LlmProviderDetailsSheet(kind: provider.kind, provider: provider),
    );
    if (changed == true && mounted) setState(_reload);
  }
}

class _LlmProviderDetailsSheet extends ConsumerStatefulWidget {
  final LlmProviderKind kind;
  final LlmProviderConfiguration? provider;

  const _LlmProviderDetailsSheet({required this.kind, this.provider});

  @override
  ConsumerState<_LlmProviderDetailsSheet> createState() =>
      _LlmProviderDetailsSheetState();
}

class _LlmProviderDetailsSheetState
    extends ConsumerState<_LlmProviderDetailsSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  final _apiKeyController = TextEditingController();
  bool _saving = false;
  bool _testing = false;
  String? _feedback;
  bool _feedbackIsError = false;

  bool get _editing => widget.provider != null;
  bool get _custom => widget.kind == LlmProviderKind.custom;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.provider?.displayName ?? widget.kind.displayName,
    );
    _baseUrlController = TextEditingController(
      text: widget.provider?.baseUrl ?? widget.kind.defaultBaseUrl,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProviderIcon(kind: widget.kind),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _editing
                        ? context.tr('编辑大模型服务', 'Edit LLM Provider')
                        : context.tr(
                            '添加 ${widget.kind.displayName}',
                            'Add ${widget.kind.displayName}',
                          ),
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              enabled: _custom,
              decoration: _inputDecoration(
                context,
                'Provider Name',
                Icons.hub_outlined,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baseUrlController,
              enabled: _custom,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _inputDecoration(context, 'Base URL', Icons.link),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              autocorrect: false,
              decoration: _inputDecoration(
                context,
                'API Key',
                Icons.key_outlined,
                hintText: _editing
                    ? context.tr(
                        '留空则保留当前密钥',
                        'Leave empty to keep the saved key',
                      )
                    : context.tr('必须填写', 'Required'),
              ),
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 12),
              Text(
                _feedback!,
                style: TextStyle(
                  color: _feedbackIsError ? Colors.redAccent : accent,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                if (_editing)
                  TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(context.tr('删除', 'Delete')),
                  ),
                const Spacer(),
                if (_editing) ...[
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: _testing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering_outlined),
                    label: Text(context.tr('测试', 'Test')),
                  ),
                  const SizedBox(width: 10),
                ],
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(context.tr('保存', 'Save')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    String label,
    IconData icon, {
    String? hintText,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: context.appBackground,
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _save() async {
    final key = _apiKeyController.text.trim();
    if (!_editing && key.isEmpty) {
      _setFeedback(context.tr('请输入 API Key。', 'Enter an API Key.'), true);
      return;
    }
    if (_nameController.text.trim().isEmpty ||
        _baseUrlController.text.trim().isEmpty) {
      _setFeedback(
        context.tr(
          'Provider 名称和 Base URL 不能为空。',
          'Provider name and Base URL are required.',
        ),
        true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final service = ref.read(openAiCompatibleExplanationProvider);
      if (_editing) {
        await service.updateProvider(
          provider: LlmProviderConfiguration(
            id: widget.provider!.id,
            kind: widget.kind,
            displayName: _nameController.text.trim(),
            baseUrl: _baseUrlController.text.trim(),
          ),
          apiKey: key.isEmpty ? null : key,
        );
      } else {
        await service.addProvider(
          kind: widget.kind,
          displayName: _nameController.text,
          baseUrl: _baseUrlController.text,
          apiKey: key,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _setFeedback('${context.tr('保存失败', 'Save failed')}: $error', true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      if (_apiKeyController.text.trim().isNotEmpty) {
        await ref
            .read(openAiCompatibleExplanationProvider)
            .updateProvider(
              provider: widget.provider!,
              apiKey: _apiKeyController.text,
            );
        if (!mounted) return;
        _apiKeyController.clear();
      }
      final connected = await ref
          .read(openAiCompatibleExplanationProvider)
          .validateProvider(widget.provider!);
      if (!mounted) return;
      _setFeedback(
        connected
            ? context.tr('连接正常。', 'Connection succeeded.')
            : context.tr(
                '连接失败，请检查 API Key 和网络。',
                'Connection failed. Check the API Key and network.',
              ),
        !connected,
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('删除 Provider？', 'Delete provider?')),
        content: Text(
          context.tr(
            '保存的 API Key 也会一并删除。',
            'Its saved API Key will also be removed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('删除', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(openAiCompatibleExplanationProvider)
        .removeProvider(widget.provider!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  void _setFeedback(String message, bool isError) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _feedbackIsError = isError;
    });
  }
}

class _ProviderIcon extends StatelessWidget {
  final LlmProviderKind kind;

  const _ProviderIcon({required this.kind});

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      LlmProviderKind.deepSeek => Icons.water_outlined,
      LlmProviderKind.zai => Icons.auto_awesome_outlined,
      LlmProviderKind.custom => Icons.hub_outlined,
    };
    return CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.14),
      foregroundColor: Theme.of(context).colorScheme.primary,
      child: Icon(icon, size: 21),
    );
  }
}

class _EmptyProviders extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyProviders({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_outlined, size: 44, color: context.appTextSecondary),
            const SizedBox(height: 14),
            Text(
              context.tr('尚未添加大模型服务', 'No LLM providers yet'),
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                '添加 Provider 并填写其 API Key。',
                'Add a provider and enter its API Key.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(context.tr('添加 Provider', 'Add Provider')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.tr('重试', 'Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
