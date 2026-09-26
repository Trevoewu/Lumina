import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/app_sheet.dart';
import '../../../core/app_localizations.dart';
import '../../../tts/provider_registry.dart';
import '../../../core/service_settings_controllers.dart';
import '../../widgets/design_system/settings_components.dart';

/// Key entry for one built-in voice provider. The providers themselves ship
/// with the app, so this edits credentials rather than adding a provider.
class TtsProviderEditorSheet extends ConsumerStatefulWidget {
  final String providerId;

  const TtsProviderEditorSheet({super.key, required this.providerId});

  static Future<bool?> show(
    BuildContext context, {
    required String providerId,
  }) {
    return showAppSheet<bool>(
      context: context,
      builder: (_) => TtsProviderEditorSheet(providerId: providerId),
    );
  }

  @override
  ConsumerState<TtsProviderEditorSheet> createState() =>
      _TtsProviderEditorSheetState();
}

class _TtsProviderEditorSheetState
    extends ConsumerState<TtsProviderEditorSheet> {
  final _apiKey = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await ref
        .read(ttsSettingsControllerProvider.notifier)
        .apiKeyFor(widget.providerId);
    if (!mounted) return;
    setState(() {
      if (key != null) _apiKey.text = key;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = ref.read(providerRegistryProvider).get(widget.providerId);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final isGptSovits = widget.providerId == 'gpt_sovits';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              provider?.displayName ??
                  context.tr('语音提供商', 'Voice provider', '音声プロバイダー'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              isGptSovits
                  ? context.tr(
                      '本地模型推理服务。模型权重与推理计算完全在本地设备，生成的音频自动存入本地离线缓存。',
                      'Local model inference. Weights and compute stay on your hardware, audio is cached locally.',
                      'ローカルモデル推論サービス。音声はローカルに保存されます。',
                    )
                  : context.tr(
                      '密钥只保存在本机钥匙串，模型与音色通过接口实时获取。',
                      'The key stays in this device\'s keychain; models and voices are pulled from the API.',
                      'キーは端末のキーチェーンにのみ保存され、モデルと音声はAPI从取得します。',
                    ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),

            SettingsSectionLabel(
              title: isGptSovits
                  ? context.tr(
                      '本地服务地址 (Local Server URL)',
                      'Local Server URL',
                      'ローカルサーバーURL',
                    )
                  : 'API Key',
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  key: const ValueKey('tts-api-key'),
                  controller: _apiKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: isGptSovits ? 'http://172.26.19.56:9880' : 'sk-...',
                    hintStyle: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.3),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.normal,
                    color: scheme.error,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 26),
            Material(
              color: _saving
                  ? scheme.onSurface.withValues(alpha: 0.06)
                  : scheme.onSurface,
              borderRadius: BorderRadius.circular(26),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('save-tts-provider'),
                onTap: _saving ? null : _save,
                child: SizedBox(
                  height: 52,
                  child: Center(
                    child: _saving
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.surface,
                            ),
                          )
                        : Text(
                            context.tr('保存', 'Save', '保存'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.normal,
                                  color: scheme.surface,
                                ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final controller = ref.read(ttsSettingsControllerProvider.notifier);
      await controller.setApiKey(widget.providerId, _apiKey.text);
      if (_apiKey.text.trim().isNotEmpty) {
        await controller.selectProvider(widget.providerId);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }
}
