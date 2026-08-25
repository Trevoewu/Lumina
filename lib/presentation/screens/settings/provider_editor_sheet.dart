import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/service_settings_controllers.dart';
import '../../../data/dictionary/openai_compatible_explanation_provider.dart';
import '../../widgets/design_system/settings_components.dart';

/// Add/edit sheet for an AI provider, matching the settings spec: pick a
/// preset, enter the key, pull the model list, choose a model, save.
class LlmProviderEditorSheet extends ConsumerStatefulWidget {
  /// Null when adding a provider.
  final LlmProviderConfiguration? existing;

  const LlmProviderEditorSheet({super.key, this.existing});

  static Future<bool?> show(
    BuildContext context, {
    LlmProviderConfiguration? existing,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LlmProviderEditorSheet(existing: existing),
    );
  }

  @override
  ConsumerState<LlmProviderEditorSheet> createState() =>
      _LlmProviderEditorSheetState();
}

enum _FetchState { idle, loading, done, error }

class _LlmProviderEditorSheetState
    extends ConsumerState<LlmProviderEditorSheet> {
  late LlmProviderKind _kind;
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;

  _FetchState _fetch = _FetchState.idle;
  String? _fetchError;
  List<String> _models = const [];
  String? _model;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = existing?.kind ?? LlmProviderKind.deepSeek;
    _name = TextEditingController(text: existing?.displayName ?? '');
    _baseUrl = TextEditingController(text: existing?.baseUrl ?? '');
    _apiKey = TextEditingController();
    if (existing != null) _loadExisting(existing);
  }

  Future<void> _loadExisting(LlmProviderConfiguration existing) async {
    final service = ref.read(openAiCompatibleExplanationProvider);
    final key = await service.apiKeyFor(existing.id);
    final cache = await service.cachedModels(existing.id);
    final selected = await ref
        .read(providerSelectionRepositoryProvider)
        .selectedLlmModel(existing.id);
    if (!mounted) return;
    setState(() {
      if (key != null) _apiKey.text = key;
      if (cache != null && cache.models.isNotEmpty) {
        _models = cache.models;
        _model = selected ?? cache.models.first;
        _fetch = _FetchState.done;
      }
    });
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
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEdit
                  ? context.tr('编辑提供商', 'Edit provider', 'プロバイダーを編集')
                  : context.tr('添加 AI 提供商', 'Add AI provider', 'AIプロバイダーを追加'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              context.tr(
                '密钥只保存在本机钥匙串，模型列表通过接口实时获取。',
                'The key stays in this device\'s keychain; the model list is pulled from the API.',
                'キーは端末のキーチェーンにのみ保存され、モデル一覧はAPIから取得します。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),

            const SizedBox(height: 22),
            SettingsSectionLabel(title: context.tr('预设', 'Preset', 'プリセット')),
            // The app ships one more preset than the spec drew, so the chips
            // size to their labels and wrap instead of being squeezed equal.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in LlmProviderKind.values)
                  SettingsChip(
                    label: kind.displayName,
                    selected: _kind == kind,
                    onTap: _isEdit ? null : () => _pickKind(kind),
                  ),
              ],
            ),

            if (_kind == LlmProviderKind.custom) ...[
              SettingsSectionLabel(title: context.tr('名称', 'Name', '名称')),
              _Field(
                controller: _name,
                hint: context.tr(
                  '例如 本地 vLLM',
                  'e.g. Local vLLM',
                  '例：ローカル vLLM',
                ),
              ),
              const SettingsSectionLabel(title: 'Base URL'),
              _Field(
                controller: _baseUrl,
                hint: 'https://api.example.com/v1',
                mono: true,
                onChanged: (_) => setState(() => _fetch = _FetchState.idle),
              ),
            ],

            const SettingsSectionLabel(title: 'API Key'),
            _Field(
              key: const ValueKey('provider-api-key'),
              controller: _apiKey,
              hint: 'sk-...',
              mono: true,
              onChanged: (_) => setState(() => _fetch = _FetchState.idle),
            ),

            const SizedBox(height: 20),
            _FetchButton(
              state: _fetch,
              onTap: _fetch == _FetchState.loading ? null : _fetchModels,
            ),

            if (_fetch == _FetchState.done || _fetch == _FetchState.error) ...[
              const SizedBox(height: 12),
              _ResultNote(
                error: _fetch == _FetchState.error,
                message: _fetch == _FetchState.error
                    ? (_fetchError ??
                          context.tr(
                            '获取失败 · 缺少 API Key',
                            'Could not connect · missing API key',
                            '取得に失敗 · APIキーがありません',
                          ))
                    : context.tr(
                        '连接成功 · 返回 ${_models.length} 个模型',
                        'Connected · ${_models.length} models returned',
                        '接続成功 · ${_models.length} 件のモデル',
                      ),
              ),
            ],
            if (_fetch == _FetchState.done && _models.isNotEmpty) ...[
              SettingsSectionLabel(
                title: context.tr('选择模型', 'Choose a model', 'モデルを選択'),
              ),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final model in _models)
                    SettingsChip(
                      label: model,
                      selected: _model == model,
                      onTap: () => setState(() => _model = model),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 26),
            _SaveButton(
              label: _isEdit
                  ? context.tr('保存修改', 'Save changes', '変更を保存')
                  : context.tr('添加', 'Add', '追加'),
              enabled: _model != null && !_saving,
              busy: _saving,
              onTap: _save,
            ),
            if (_isEdit) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _saving ? null : _remove,
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                child: Text(
                  context.tr('删除提供商', 'Remove provider', 'プロバイダーを削除'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _pickKind(LlmProviderKind kind) {
    setState(() {
      _kind = kind;
      _fetch = _FetchState.idle;
      _models = const [];
      _model = null;
      if (kind != LlmProviderKind.custom) {
        _name.text = kind.displayName;
        _baseUrl.text = kind.defaultBaseUrl;
      } else {
        _name.text = '';
        _baseUrl.text = '';
      }
    });
  }

  Future<void> _fetchModels() async {
    final key = _apiKey.text.trim();
    if (key.isEmpty) {
      setState(() {
        _fetch = _FetchState.error;
        _fetchError = context.tr(
          '获取失败 · 缺少 API Key',
          'Could not connect · missing API key',
          '取得に失敗 · APIキーがありません',
        );
      });
      return;
    }
    setState(() {
      _fetch = _FetchState.loading;
      _fetchError = null;
    });

    final controller = ref.read(llmSettingsControllerProvider.notifier);
    final service = ref.read(openAiCompatibleExplanationProvider);
    try {
      // Adding needs a saved provider before its key can be used, so the draft
      // is persisted first and then reconciled when the sheet is saved.
      var target = widget.existing;
      if (target == null) {
        target = await controller.addProvider(
          kind: _kind,
          apiKey: key,
          displayName: _kind == LlmProviderKind.custom
              ? _name.text.trim()
              : null,
          baseUrl: _kind == LlmProviderKind.custom
              ? _baseUrl.text.trim()
              : null,
        );
        _created = target;
      } else {
        await controller.updateProvider(provider: target, apiKey: key);
      }
      final result = await service.refreshModels(target);
      if (!mounted) return;
      if (result.failed) {
        setState(() {
          _fetch = _FetchState.error;
          _fetchError = result.error.toString();
        });
        return;
      }
      setState(() {
        _models = [for (final m in result.models) m.id];
        _model = _models.contains(_model) ? _model : _models.firstOrNull;
        _fetch = _FetchState.done;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _fetch = _FetchState.error;
        _fetchError = error.toString();
      });
    }
  }

  /// Provider row created while fetching models for a brand new entry.
  LlmProviderConfiguration? _created;

  Future<void> _save() async {
    final model = _model;
    final target = widget.existing ?? _created;
    if (model == null || target == null) return;
    setState(() => _saving = true);
    final controller = ref.read(llmSettingsControllerProvider.notifier);
    try {
      await controller.selectModelFor(target.id, model);
      await controller.selectProvider(target.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fetch = _FetchState.error;
        _fetchError = error.toString();
      });
    }
  }

  Future<void> _remove() async {
    final target = widget.existing;
    if (target == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('删除提供商？', 'Remove provider?', 'プロバイダーを削除？')),
        content: Text(
          context.tr(
            '将删除 ${target.displayName} 的 API Key 与模型选择。书库与生词本不受影响。',
            'This removes the API key and model choice for ${target.displayName}. Your library and vocabulary are untouched.',
            '${target.displayName} のAPIキーとモデル選択を削除します。ライブラリと単語帳は影響を受けません。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel', 'キャンセル')),
          ),
          FilledButton(
            key: const ValueKey('confirm-remove-provider'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(context.tr('删除', 'Remove', '削除')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    await ref
        .read(llmSettingsControllerProvider.notifier)
        .removeProvider(target.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool mono;
  final ValueChanged<String>? onChanged;

  const _Field({
    super.key,
    required this.controller,
    required this.hint,
    this.mono = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autocorrect: false,
        enableSuggestions: false,
        style: TextStyle(
          fontSize: mono ? 14 : 15,
          fontFamily: mono ? 'monospace' : null,
          color: scheme.onSurface,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: hint,
          hintStyle: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.3),
            fontFamily: mono ? 'monospace' : null,
          ),
        ),
      ),
    );
  }
}

class _FetchButton extends StatelessWidget {
  final _FetchState state;
  final VoidCallback? onTap;

  const _FetchButton({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loading = state == _FetchState.loading;
    final done = state == _FetchState.done;
    final background = loading || done
        ? scheme.onSurface.withValues(alpha: 0.06)
        : scheme.primary;
    final foreground = loading
        ? scheme.onSurfaceVariant
        : done
        ? scheme.onSurface
        : scheme.onPrimary;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(25),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('fetch-provider-models'),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading) ...[
                SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Text(
                loading
                    ? context.tr('正在获取模型…', 'Fetching models…', 'モデルを取得中…')
                    : done
                    ? context.tr(
                        '重新获取模型列表',
                        'Fetch the model list again',
                        'モデル一覧を再取得',
                      )
                    : context.tr('获取模型列表', 'Fetch model list', 'モデル一覧を取得'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultNote extends StatelessWidget {
  final bool error;
  final String message;

  const _ResultNote({required this.error, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: error
            ? scheme.error.withValues(alpha: 0.1)
            : scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: error ? scheme.error : scheme.onSurface,
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  const _SaveButton({
    required this.label,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: enabled
          ? scheme.onSurface
          : scheme.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('save-provider'),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          height: 52,
          child: Center(
            child: busy
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.surface,
                    ),
                  )
                : Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: enabled
                          ? scheme.surface
                          : scheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
