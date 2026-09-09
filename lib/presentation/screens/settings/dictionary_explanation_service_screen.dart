import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/service_settings_controllers.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/settings_components.dart';
import 'provider_editor_sheet.dart';

/// The "AI 模型" pane: a list of configured providers, the active one expanded
/// to its model chips, and a button to add another.
class DictionaryExplanationServiceScreen extends ConsumerWidget {
  const DictionaryExplanationServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(llmSettingsControllerProvider);
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(llmSettingsControllerProvider.notifier);

    return CollapsingPageScaffold(
      title: context.tr('AI 模型', 'AI Model', 'AIモデル'),
      showBackButton: true,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            SettingsErrorState(error: error, onRetry: controller.reload),
        data: (data) => ListView(
          padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                context.tr(
                  '用于书籍与播客摘要、以及 Ask AI。添加提供商后从接口拉取可用模型。',
                  'Powers book and podcast summaries plus Ask AI. Add a provider, then pull its available models.',
                  '書籍・Podcastの要約と Ask AI に使われます。プロバイダーを追加してモデル一覧を取得します。',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ),

            SettingsSectionLabel(
              title: context.tr(
                '已添加的提供商',
                'Configured providers',
                '追加済みのプロバイダー',
              ),
            ),
            for (final card in data.cards) ...[
              _ProviderCard(
                card: card,
                onSelect: card.active
                    ? null
                    : () => _activate(context, controller, card.id),
                onEdit: () => LlmProviderEditorSheet.show(
                  context,
                  existing: card.configuration,
                ),
                onRefresh: () => _refresh(context, controller, card.id),
                onPickModel: (model) =>
                    controller.selectModelFor(card.id, model),
              ),
              const SizedBox(height: 10),
            ],

            _AddProviderButton(
              label: context.tr('添加提供商', 'Add provider', 'プロバイダーを追加'),
              onTap: () => LlmProviderEditorSheet.show(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activate(
    BuildContext context,
    LlmSettingsController controller,
    String providerId,
  ) async {
    try {
      await controller.selectProvider(providerId);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _refresh(
    BuildContext context,
    LlmSettingsController controller,
    String providerId,
  ) async {
    final error = await controller.refreshModels(providerId);
    if (error == null || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$error')));
  }
}

class _ProviderCard extends StatelessWidget {
  final LlmProviderCardData card;
  final VoidCallback? onSelect;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;
  final ValueChanged<String> onPickModel;

  const _ProviderCard({
    required this.card,
    required this.onSelect,
    required this.onEdit,
    required this.onRefresh,
    required this.onPickModel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(18);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('llm-provider-${card.id}'),
          onTap: onSelect,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: card.active ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SettingsRadio(selected: card.active),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  card.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _Tag(label: card.tag),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _meta(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SquareButton(
                      icon: AppIcons.pencilEdit02,
                      onTap: onEdit,
                      semanticLabel: context.tr('编辑', 'Edit', '編集'),
                    ),
                  ],
                ),
                if (card.active) ...[
                  const SizedBox(height: 15),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: scheme.onSurface.withValues(alpha: 0.06),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('模型', 'Models', 'モデル'),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                letterSpacing: 1.3,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      InkWell(
                        key: ValueKey('llm-refresh-${card.id}'),
                        onTap: card.refreshing ? null : onRefresh,
                        child: Text(
                          card.refreshing
                              ? context.tr('获取中…', 'Fetching…', '取得中…')
                              : context.tr('刷新列表', 'Refresh list', '一覧を更新'),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: card.refreshing
                                    ? scheme.onSurface.withValues(alpha: 0.3)
                                    : scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  if (card.models.isEmpty)
                    Text(
                      context.tr(
                        '还没有模型列表，点「刷新列表」从接口获取。',
                        'No model list yet — tap Refresh list to pull it from the API.',
                        'モデル一覧がありません。「一覧を更新」で取得してください。',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final model in card.models)
                          SettingsChip(
                            label: model,
                            selected: card.selectedModelId == model,
                            onTap: () => onPickModel(model),
                          ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _meta(BuildContext context) {
    final parts = <String>[
      card.selectedModelId ?? context.tr('未选择模型', 'No model', 'モデル未選択'),
      context.tr(
        '${card.models.length} 个模型',
        '${card.models.length} models',
        '${card.models.length} 件のモデル',
      ),
    ];
    final syncedAt = card.syncedAt;
    if (syncedAt != null) {
      parts.add(
        context.tr(
          '同步于 ${_ago(context, syncedAt)}',
          'synced ${_ago(context, syncedAt)}',
          '${_ago(context, syncedAt)}に同期',
        ),
      );
    }
    return parts.join(' · ');
  }

  String _ago(BuildContext context, DateTime time) {
    final delta = DateTime.now().difference(time);
    if (delta.inMinutes < 1) {
      return context.tr('刚刚', 'just now', 'たった今');
    }
    if (delta.inHours < 1) {
      return context.tr(
        '${delta.inMinutes} 分钟前',
        '${delta.inMinutes}m ago',
        '${delta.inMinutes}分前',
      );
    }
    if (delta.inDays < 1) {
      return context.tr(
        '${delta.inHours} 小时前',
        '${delta.inHours}h ago',
        '${delta.inHours}時間前',
      );
    }
    return context.tr(
      '${delta.inDays} 天前',
      '${delta.inDays}d ago',
      '${delta.inDays}日前',
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontFamily: 'monospace',
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final AppIconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  const _SquareButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: AppIcon(icon, size: 16, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _AddProviderButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddProviderButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.onSurface.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('add-llm-provider'),
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.12),
              width: 1.6,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                AppIcons.add01,
                size: 17,
                color: scheme.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
