import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/service_settings_controllers.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/settings_components.dart';

class AsrServiceScreen extends ConsumerWidget {
  const AsrServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(asrSettingsControllerProvider);
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(asrSettingsControllerProvider.notifier);

    return CollapsingPageScaffold(
      title: context.tr('语音识别', 'Speech Recognition', '音声認識'),
      showBackButton: true,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            SettingsErrorState(error: error, onRetry: controller.reload),
        data: (data) => ListView(
          padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
              child: Text(
                context.tr(
                  '播客转录在设备上完成。模型越大越准，也越慢、越占空间。',
                  'Podcast transcription runs on this device. Bigger models are more accurate, but slower and larger.',
                  'Podcastの文字起こしは端末内で実行されます。大きいモデルほど正確ですが、遅く容量も必要です。',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ),
            if (data.operationError != null) ...[
              SizedBox(height: design.spaceMd),
              SettingsFeedbackBanner(
                message: data.operationError!,
                error: true,
              ),
            ],
            const SizedBox(height: 18),
            for (final model in data.models) ...[
              _AsrModelCard(
                model: model,
                note: _modelNote(context, model.id),
                onSelect: model.installed && !model.active
                    ? () => controller.selectModel(model.id)
                    : null,
                onDownload: !model.installed && !model.downloading
                    ? () => controller.installModel(model.id)
                    : null,
              ),
              const SizedBox(height: 10),
            ],

            SettingsSectionLabel(
              title: context.tr('分段长度', 'Slice Length', '分割の長さ'),
            ),
            SettingsCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('音频切片', 'Audio slice', '音声スライス'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        context.tr(
                          '${data.chunkSeconds} 秒',
                          '${data.chunkSeconds}s',
                          '${data.chunkSeconds} 秒',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final seconds
                          in AsrSettingsController.supportedChunkSeconds)
                        SettingsChip(
                          label: context.tr(
                            '$seconds 秒',
                            '${seconds}s',
                            '$seconds 秒',
                          ),
                          selected: data.chunkSeconds == seconds,
                          onTap: () => controller.setChunkSeconds(seconds),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _chunkHint(context, data.chunkSeconds),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _modelNote(BuildContext context, String id) => switch (id) {
    'tiny' => context.tr(
      '最快，适合英文清晰人声',
      'Fastest, best for clear English speech',
      '最速。明瞭な英語音声向け',
    ),
    'base' => context.tr(
      '平衡选择，多语言可用',
      'Balanced, works across languages',
      'バランス型。多言語対応',
    ),
    'small' => context.tr(
      '中文与口音更稳',
      'Steadier on Chinese and accents',
      '中国語やなまりに強い',
    ),
    _ => context.tr(
      '最准，转录约为实时的 1.4 倍',
      'Most accurate, about 1.4x realtime',
      '最も正確。実時間の約1.4倍',
    ),
  };

  String _chunkHint(BuildContext context, int seconds) {
    if (seconds <= 15) {
      return context.tr(
        '短切片内存占用低、失败重试快，但跨句断点会多一些。',
        'Short slices use less memory and retry quickly, but break across sentences more often.',
        '短いスライスはメモリが少なく再試行も速い一方、文の途中で切れやすくなります。',
      );
    }
    if (seconds >= 120) {
      return context.tr(
        '长切片上下文最完整，标点更准，单块失败需重跑整块。',
        'Long slices keep the most context and punctuate better, but a failure re-runs the whole slice.',
        '長いスライスは文脈が保たれ句読点も正確ですが、失敗すると丸ごとやり直しになります。',
      );
    }
    final blocks = (3600 / seconds).round();
    return context.tr(
      '约 $blocks 块/小时音频，兼顾准确度与重试成本。',
      'About $blocks slices per hour of audio, balancing accuracy against retry cost.',
      '音声1時間あたり約$blocksブロック。精度と再試行コストのバランスが取れます。',
    );
  }
}

class _AsrModelCard extends StatelessWidget {
  final AsrModelViewData model;
  final String note;
  final VoidCallback? onSelect;
  final VoidCallback? onDownload;

  const _AsrModelCard({
    required this.model,
    required this.note,
    required this.onSelect,
    required this.onDownload,
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
          key: ValueKey('asr-model-${model.id}'),
          onTap: onSelect,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: model.active ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SettingsRadio(
                      selected: model.active,
                      enabled: model.installed,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: Text(
                                  model.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.normal),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatBytes(model.expectedBytes),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontFamily: 'monospace',
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            note,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _action(context),
                  ],
                ),
                if (model.downloading) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: model.progress,
                      minHeight: 5,
                      backgroundColor: scheme.onSurface.withValues(alpha: 0.07),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (model.downloading) {
      final percent = model.progress == null
          ? '…'
          : '${(model.progress! * 100).round()}%';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          percent,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.normal,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (!model.installed) {
      return Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('asr-download-${model.id}'),
          onTap: onDownload,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              context.tr('下载', 'Download', 'ダウンロード'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.normal,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
      );
    }
    if (model.active) {
      return Text(
        context.tr('使用中', 'In use', '使用中'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontFamily: 'monospace',
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  static String _formatBytes(int bytes) {
    const mb = 1024 * 1024;
    if (bytes >= 1024 * mb) {
      return '${(bytes / (1024 * mb)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / mb).round()} MB';
  }
}
