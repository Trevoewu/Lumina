import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/dictionary/openai_compatible_explanation_provider.dart';
import '../../widgets/collapsing_page_scaffold.dart';

class LlmModelScreen extends ConsumerStatefulWidget {
  const LlmModelScreen({super.key});

  @override
  ConsumerState<LlmModelScreen> createState() => _LlmModelScreenState();
}

class _LlmModelScreenState extends ConsumerState<LlmModelScreen> {
  late Future<List<LlmProviderModels>> _modelsFuture;
  String? _activeProviderId;
  String? _activeModel;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final service = ref.read(openAiCompatibleExplanationProvider);
    _modelsFuture = service.fetchAllModels();
    Future.wait([service.activeProvider, service.model]).then((values) {
      if (!mounted) return;
      setState(() {
        _activeProviderId = (values[0] as LlmProviderConfiguration?)?.id;
        _activeModel = values[1] as String;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return CollapsingPageScaffold(
      title: context.tr('模型', 'Model'),
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: context.tr('刷新模型', 'Refresh Models'),
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(_reload),
        ),
      ],
      body: FutureBuilder<List<LlmProviderModels>>(
        future: _modelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ModelMessage(
              icon: Icons.error_outline,
              message: '${snapshot.error}',
            );
          }
          final groups = snapshot.data ?? const [];
          if (groups.isEmpty) {
            return _ModelMessage(
              icon: Icons.hub_outlined,
              message: context.tr(
                '请先添加 LLM Provider 和 API Key。',
                'Add an LLM provider and API Key first.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _modelsFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              itemCount: groups.length,
              itemBuilder: (context, index) => _buildGroup(groups[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroup(LlmProviderModels group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
            child: Text(
              '${group.provider.displayName.toUpperCase()} · ${group.provider.hostLabel}',
              style: TextStyle(
                color: context.appTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (group.failed)
            Material(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(8),
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text(context.tr('模型加载失败', 'Failed to load models')),
                subtitle: Text(
                  '${group.error}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: context.tr('重试', 'Retry'),
                  onPressed: () => setState(_reload),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            )
          else if (group.models.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                context.tr(
                  '此 Provider 没有返回可用模型。',
                  'This provider returned no models.',
                ),
                style: TextStyle(color: context.appTextSecondary),
              ),
            )
          else
            Material(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0; index < group.models.length; index++) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        color: context.appSurfaceHighlight,
                      ),
                    _buildModelTile(group.provider, group.models[index]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModelTile(
    LlmProviderConfiguration provider,
    LlmModelOption model,
  ) {
    final selected =
        provider.id == _activeProviderId && model.id == _activeModel;
    return ListTile(
      key: ValueKey('llm-model-${provider.id}-${model.id}'),
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        model.id,
        style: TextStyle(
          color: context.appTextPrimary,
          fontSize: 16,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: model.ownedBy?.isNotEmpty == true
          ? Text(
              model.ownedBy!,
              style: TextStyle(color: context.appTextSecondary, fontSize: 12),
            )
          : null,
      trailing: selected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => _select(provider, model),
    );
  }

  Future<void> _select(
    LlmProviderConfiguration provider,
    LlmModelOption model,
  ) async {
    await ref
        .read(openAiCompatibleExplanationProvider)
        .selectModel(providerId: provider.id, model: model.id);
    if (!mounted) return;
    setState(() {
      _activeProviderId = provider.id;
      _activeModel = model.id;
    });
  }
}

class _ModelMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _ModelMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: context.appTextSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
