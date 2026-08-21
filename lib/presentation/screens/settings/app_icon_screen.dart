import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../services/app_icon_service.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/app_surface.dart';

class AppIconScreen extends ConsumerStatefulWidget {
  const AppIconScreen({super.key});

  @override
  ConsumerState<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends ConsumerState<AppIconScreen> {
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
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return CollapsingPageScaffold(
      title: context.tr('App 图标', 'App Icon', 'アプリアイコン'),
      showBackButton: true,
      body: ListView(
        padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
        children: [
          AppSurface(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.42),
            padding: EdgeInsets.all(design.spaceLg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.apps_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: design.spaceMd),
                Expanded(
                  child: Text(
                    _supported
                        ? context.tr(
                            '选择后，主屏幕上的 Lumina 图标会立即更新。',
                            'Choose an icon to update Lumina on your Home Screen.',
                            '選択するとホーム画面のLuminaアイコンがすぐに更新されます。',
                          )
                        : context.tr(
                            '当前平台不支持在 App 内更换启动图标。你仍可预览全部候选。',
                            'This platform does not support changing the launcher icon in the app. You can still preview every option.',
                            'このプラットフォームではアプリ内でランチャーアイコンを変更できません。すべての候補をプレビューできます。',
                          ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: design.spaceLg),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 600 ? 4 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: appIconOptions.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: design.spaceMd,
                    mainAxisSpacing: design.spaceMd,
                    childAspectRatio: 0.88,
                  ),
                  itemBuilder: (context, index) => _IconChoice(
                    option: appIconOptions[index],
                    selected: _selectedId == appIconOptions[index].id,
                    applying: _applyingId == appIconOptions[index].id,
                    enabled: _supported && _applyingId == null,
                    onTap: () => _apply(appIconOptions[index]),
                  ),
                );
              },
            ),
        ],
      ),
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
    final design = context.appDesign;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: context.tr(
        option.chineseLabel,
        option.englishLabel,
        option.japaneseLabel,
      ),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(design.radiusMedium),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('app-icon-${option.id}'),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: EdgeInsets.all(design.spaceMd),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(design.radiusLarge),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.asset(option.assetPath, fit: BoxFit.cover),
                    ),
                  ),
                ),
                SizedBox(height: design.spaceSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (applying)
                      const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (selected)
                      Icon(Icons.check_circle, size: 18, color: scheme.primary),
                    if (applying || selected) SizedBox(width: design.spaceXs),
                    Flexible(
                      child: Text(
                        context.tr(
                          option.chineseLabel,
                          option.englishLabel,
                          option.japaneseLabel,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
