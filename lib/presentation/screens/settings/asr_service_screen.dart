import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/service_settings_controllers.dart';
import '../../../services/podcast_transcription_service.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/app_section_header.dart';
import '../../widgets/design_system/settings_components.dart';

class AsrServiceScreen extends ConsumerWidget {
  const AsrServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(asrSettingsControllerProvider);
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return CollapsingPageScaffold(
      title: context.tr('语音转文字', 'Speech to Text', '音声文字起こし'),
      showBackButton: true,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SettingsErrorState(
          error: error,
          onRetry: () =>
              ref.read(asrSettingsControllerProvider.notifier).reload(),
        ),
        data: (data) => ListView(
          padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
          children: [
            ServiceStatusCard(
              cardKey: const ValueKey('asr-status-card'),
              icon: Icons.subtitles_outlined,
              title: context.tr(
                '当前转写服务',
                'Current transcription service',
                '現在の文字起こしサービス',
              ),
              provider: data.providerName,
              selection: data.modelName,
              readiness: data.readiness,
            ),
            if (data.operationError != null) ...[
              SizedBox(height: design.spaceMd),
              SettingsFeedbackBanner(
                message: data.operationError!,
                error: true,
              ),
            ],
            AppSectionHeader(title: context.tr('配置', 'Configuration', '設定')),
            SettingsGroup(
              children: [
                SettingValueRow(
                  icon: Icons.memory_outlined,
                  title: context.tr('转写服务', 'ASR service', '文字起こしサービス'),
                  subtitle: context.tr(
                    '音频与字幕只在本机处理',
                    'Audio and transcripts stay on this device',
                    '音声と文字起こしはこの端末でのみ処理',
                  ),
                  value: data.providerName,
                ),
                SettingValueRow(
                  icon: Icons.psychology_outlined,
                  title: context.tr('模型', 'Model', 'モデル'),
                  subtitle: context.tr(
                    '多语言通用模型',
                    'General multilingual model',
                    '多言語汎用モデル',
                  ),
                  value: data.modelName,
                ),
                SettingValueRow(
                  rowKey: const ValueKey('asr-chunk-settings'),
                  icon: Icons.segment_outlined,
                  title: context.tr(
                    '字幕更新粒度',
                    'Transcript update interval',
                    '文字起こしの更新間隔',
                  ),
                  subtitle: context.tr(
                    '分段完成后立即显示已缓存字幕',
                    'Show each cached chunk as soon as it finishes',
                    'セグメント完了後すぐに保存済みの文字起こしを表示',
                  ),
                  value: context.tr(
                    '${data.chunkMinutes} 分钟',
                    '${data.chunkMinutes} min',
                    '${data.chunkMinutes}分',
                  ),
                  onTap: () => _chooseChunkMinutes(context, ref, data),
                ),
                SettingValueRow(
                  rowKey: const ValueKey('asr-language-settings'),
                  icon: Icons.translate_outlined,
                  title: context.tr('语言识别', 'Language detection', '言語認識'),
                  subtitle: context.tr(
                    '节目语言不准确时可改为自动识别',
                    'Use automatic detection when feed metadata is inaccurate',
                    '番組の言語が不正確な場合は自動認識に変更',
                  ),
                  value: _languageLabel(context, data.languagePreference),
                  onTap: () => _chooseLanguage(context, ref, data),
                ),
              ],
            ),
            AppSectionHeader(
              title: context.tr('模型管理', 'Model management', 'モデル管理'),
            ),
            SettingsGroup(
              children: [
                SettingValueRow(
                  rowKey: const ValueKey('asr-model-status'),
                  icon: data.modelInstalled
                      ? Icons.download_done_rounded
                      : Icons.cloud_download_outlined,
                  title: data.modelName,
                  subtitle: data.modelInstalled
                      ? context.tr(
                          '已保存在本机 · ${_formatBytes(data.installedBytes)}',
                          'Stored on device · ${_formatBytes(data.installedBytes)}',
                          '端末に保存済み · ${_formatBytes(data.installedBytes)}',
                        )
                      : context.tr(
                          '首次转写前需要下载，约 ${_formatBytes(data.expectedBytes)}',
                          'Required before first use · about ${_formatBytes(data.expectedBytes)}',
                          '初回使用前にダウンロードが必要 · 約${_formatBytes(data.expectedBytes)}',
                        ),
                  value: data.modelInstalled
                      ? context.tr('已安装', 'Installed', 'インストール済み')
                      : context.tr('未安装', 'Not installed', '未インストール'),
                ),
                if (data.operationInProgress)
                  Padding(
                    padding: EdgeInsets.all(design.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.operationMessage ??
                              context.tr('正在处理模型', 'Managing model', 'モデルを処理中'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        SizedBox(height: design.spaceSm),
                        LinearProgressIndicator(value: data.operationProgress),
                        if (data.operationProgress != null) ...[
                          SizedBox(height: design.spaceXs),
                          Text(
                            '${(data.operationProgress! * 100).round()}%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: design.spaceMd),
            if (!data.operationInProgress)
              data.modelInstalled
                  ? OutlinedButton.icon(
                      key: const ValueKey('delete-asr-model'),
                      onPressed: () => _confirmDelete(context, ref),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(
                        context.tr(
                          '删除本地模型',
                          'Delete local model',
                          'ローカルモデルを削除',
                        ),
                      ),
                    )
                  : FilledButton.icon(
                      key: const ValueKey('download-asr-model'),
                      onPressed: () => ref
                          .read(asrSettingsControllerProvider.notifier)
                          .installModel(),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(
                        context.tr(
                          '下载 Whisper Base',
                          'Download Whisper Base',
                          'Whisper Baseをダウンロード',
                        ),
                      ),
                    ),
            AppSectionHeader(title: context.tr('隐私', 'Privacy', 'プライバシー')),
            SettingsGroup(
              children: [
                SettingValueRow(
                  icon: Icons.lock_outline_rounded,
                  title: context.tr('完全本地处理', 'Fully on-device', '端末内で処理'),
                  subtitle: context.tr(
                    '模型下载完成后，Podcast 音频不会发送到第三方 ASR 服务。',
                    'After the model is installed, podcast audio is not sent to a third-party ASR service.',
                    'モデルのインストール後、Podcast音声は第三者のASRサービスに送信されません。',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _languageLabel(BuildContext context, String preference) {
    return preference == PodcastTranscriptionService.automaticLanguagePreference
        ? context.tr('自动识别', 'Automatic', '自動認識')
        : context.tr('优先节目语言', 'Podcast metadata first', '番組の言語を優先');
  }

  static Future<void> _chooseChunkMinutes(
    BuildContext context,
    WidgetRef ref,
    AsrSettingsState state,
  ) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                sheetContext.tr(
                  '字幕更新粒度',
                  'Transcript update interval',
                  '文字起こしの更新間隔',
                ),
              ),
              subtitle: Text(
                sheetContext.tr(
                  '较短分段更快显示首批字幕，但会增加模型重复加载。',
                  'Shorter chunks reveal text sooner but reload the model more often.',
                  '短いセグメントは文字起こしの表示が速い一方、モデルの再読み込みが増えます。',
                ),
              ),
            ),
            RadioGroup<int>(
              groupValue: state.chunkMinutes,
              onChanged: (value) => Navigator.of(sheetContext).pop(value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final minutes
                      in AsrSettingsController.supportedChunkMinutes)
                    RadioListTile<int>(
                      value: minutes,
                      title: Text(
                        sheetContext.tr(
                          '$minutes 分钟',
                          '$minutes minutes',
                          '$minutes分',
                        ),
                      ),
                      subtitle:
                          minutes ==
                              PodcastTranscriptionService.defaultChunkMinutes
                          ? Text(sheetContext.tr('推荐', 'Recommended', 'おすすめ'))
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await ref
        .read(asrSettingsControllerProvider.notifier)
        .setChunkMinutes(selected);
  }

  static Future<void> _chooseLanguage(
    BuildContext context,
    WidgetRef ref,
    AsrSettingsState state,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<String>(
              groupValue: state.languagePreference,
              onChanged: (value) => Navigator.of(sheetContext).pop(value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    value:
                        PodcastTranscriptionService.podcastLanguagePreference,
                    title: Text(
                      sheetContext.tr(
                        '优先节目语言',
                        'Podcast metadata first',
                        '番組の言語を優先',
                      ),
                    ),
                    subtitle: Text(
                      sheetContext.tr(
                        '使用 RSS 中的语言，缺失时再自动选择。',
                        'Use the RSS language, then fall back automatically.',
                        'RSSの言語を使い、ない場合は自動選択します。',
                      ),
                    ),
                  ),
                  RadioListTile<String>(
                    value:
                        PodcastTranscriptionService.automaticLanguagePreference,
                    title: Text(
                      sheetContext.tr('自动识别', 'Automatic detection', '自動認識'),
                    ),
                    subtitle: Text(
                      sheetContext.tr(
                        '忽略 RSS 语言信息。',
                        'Ignore language metadata from the feed.',
                        'フィードの言語情報を無視します。',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await ref
        .read(asrSettingsControllerProvider.notifier)
        .setLanguagePreference(selected);
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.tr(
            '删除 Whisper 模型？',
            'Delete Whisper model?',
            'Whisperモデルを削除しますか？',
          ),
        ),
        content: Text(
          dialogContext.tr(
            '已缓存的字幕不会删除；下次需要本地转写时必须重新下载模型。',
            'Cached transcripts will remain. The model must be downloaded again before another local transcription.',
            '保存済みの文字起こしは削除されません。次回の端末内文字起こし時にモデルを再ダウンロードしてください。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.tr('取消', 'Cancel', 'キャンセル')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.tr('删除', 'Delete', '削除')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(asrSettingsControllerProvider.notifier).deleteModel();
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  final mib = bytes / (1024 * 1024);
  return '${mib.toStringAsFixed(mib >= 100 ? 0 : 1)} MB';
}
