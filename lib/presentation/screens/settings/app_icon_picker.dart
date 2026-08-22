import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../services/app_icon_service.dart';

/// Horizontal strip of launcher-icon choices, shown inside the appearance
/// settings page. Platforms that cannot swap the launcher icon still render
/// the strip so every candidate stays previewable, just without tap handling.
class AppIconPicker extends ConsumerStatefulWidget {
  const AppIconPicker({super.key});

  @override
  ConsumerState<AppIconPicker> createState() => _AppIconPickerState();
}

class _AppIconPickerState extends ConsumerState<AppIconPicker> {
  bool _loading = true;
  bool _supported = false;
  String _selectedId = 'default';
  String? _applyingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gateway = ref.read(appIconGatewayProvider);
    final supported = await gateway.isSupported();
    final selectedId = supported ? await gateway.currentIconId() : 'default';
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _selectedId = selectedId;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Laid out eagerly rather than with a lazy ListView so every candidate
        // stays present (and reachable by ensureVisible) while off-screen.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < appIconOptions.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _IconChoice(
                  option: appIconOptions[i],
                  selected: _selectedId == appIconOptions[i].id,
                  applying: _applyingId == appIconOptions[i].id,
                  enabled: _supported && _applyingId == null,
                  onTap: () => _apply(appIconOptions[i]),
                ),
              ],
            ],
          ),
        ),
        if (!_supported)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
            child: Text(
              context.tr(
                '当前平台不支持在 App 内更换启动图标。你仍可预览全部候选。',
                'This platform does not support changing the launcher icon in the app. You can still preview every option.',
                'このプラットフォームではアプリ内でランチャーアイコンを変更できません。すべての候補をプレビューできます。',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _apply(AppIconOption option) async {
    if (!_supported || _applyingId != null || option.id == _selectedId) return;
    final successMessage = context.tr(
      '已更换 App 图标',
      'App icon changed',
      'アプリアイコンを変更しました',
    );
    final failurePrefix = context.tr(
      '无法更换 App 图标',
      'Could not change the app icon',
      'アプリアイコンを変更できませんでした',
    );
    setState(() => _applyingId = option.id);
    try {
      final gateway = ref.read(appIconGatewayProvider);
      await gateway.setIcon(option.id);
      final selectedId = await gateway.currentIconId();
      if (!mounted) return;
      setState(() {
        _selectedId = selectedId;
        _applyingId = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _applyingId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$failurePrefix: $error')));
    }
  }
}

class _IconChoice extends StatelessWidget {
  final AppIconOption option;
  final bool selected;
  final bool applying;
  final bool enabled;
  final VoidCallback onTap;

  const _IconChoice({
    required this.option,
    required this.selected,
    required this.applying,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = context.tr(
      option.chineseLabel,
      option.englishLabel,
      option.japaneseLabel,
    );
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        key: ValueKey('app-icon-${option.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 74,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The spec rings the active tile with a gap: a 2.5px accent
              // border separated from the artwork by a same-width inset.
              Container(
                width: 71,
                height: 71,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: selected ? scheme.primary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(option.assetPath, fit: BoxFit.cover),
                      if (applying)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: const Center(
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
