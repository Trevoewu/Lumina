import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/service_settings_controllers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../services/app_log_service.dart';
import '../../../tts/models/tts_capabilities.dart';
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/settings_components.dart';
import '../../widgets/disk_cached_network_image.dart';

class VoiceLibraryScreen extends ConsumerStatefulWidget {
  final bool guidedSelection;
  final bool syncOnOpen;

  const VoiceLibraryScreen({
    super.key,
    this.guidedSelection = false,
    this.syncOnOpen = false,
  });

  @override
  ConsumerState<VoiceLibraryScreen> createState() => _VoiceLibraryScreenState();
}

class _VoiceLibraryScreenState extends ConsumerState<VoiceLibraryScreen> {
  bool _loadingPreset = false;
  bool _creatingVoice = false;
  bool _cloningVoice = false;
  String? _activeVoiceId;
  String? _pendingVoiceId;
  String? _feedbackMessage;
  bool _feedbackIsError = false;
  final AudioPlayer _previewPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _previewStateSubscription;
  String? _playingVoiceId;
  final Set<File> _temporaryPreviews = {};
  late Future<List<drift_db.Voice>> _voicesFuture;
  final _descriptionController = TextEditingController();
  final _nameController = TextEditingController();
  final _cloneNameController = TextEditingController();
  final _cloneTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final providerId = ref.read(activeTtsProviderProvider).id;
    _voicesFuture = ref
        .read(appDatabaseProvider)
        .getVoicesByProvider(providerId);
    _loadActiveVoice();
    _previewStateSubscription = _previewPlayer.playerStateStream.listen((
      state,
    ) {
      if (!mounted || state.processingState != ProcessingState.completed) {
        return;
      }
      setState(() => _playingVoiceId = null);
    });
    if (widget.syncOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncPresetVoices(providerId);
      });
    }
  }

  @override
  void dispose() {
    _previewStateSubscription?.cancel();
    _previewPlayer.dispose();
    for (final file in _temporaryPreviews) {
      unawaited(file.delete().catchError((_) => file));
    }
    _descriptionController.dispose();
    _nameController.dispose();
    _cloneNameController.dispose();
    _cloneTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(activeTtsProviderProvider);
    final capabilities = provider.capabilities;

    return CollapsingPageScaffold(
      title: widget.guidedSelection
          ? context.tr('选择朗读音色', 'Choose a Reading Voice', '読み上げ音声を選択')
          : context.tr('音色库', 'Voice Library', '音声ライブラリ'),
      showBackButton: true,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.guidedSelection) ...[
                    SetupProgressHeader(
                      title: context.tr(
                        '语音设置进度',
                        'Voice setup progress',
                        '音声設定の進捗',
                      ),
                      steps: [
                        'Provider',
                        context.tr('密钥', 'Key', 'キー'),
                        context.tr('模型', 'Model', 'モデル'),
                        'Voice',
                      ],
                      currentStep: 3,
                    ),
                    const SizedBox(height: 12),
                    SettingsFeedbackBanner(
                      message: context.tr(
                        '可用音色会从 ${provider.displayName} 云端同步。点击一个音色完成设置。',
                        'Available voices are synced from the cloud through ${provider.displayName}. Tap one to finish setup.',
                        '${provider.displayName}から利用可能な音声を同期します。音声をタップして設定を完了してください。',
                      ),
                    ),
                  ],
                  if (!widget.guidedSelection)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.record_voice_over_outlined),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    provider.displayName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(_capabilityLine(provider.capabilities)),
                            if (widget.guidedSelection) ...[
                              const SizedBox(height: 8),
                              Text(
                                context.tr(
                                  '正在从云端同步可用音色。点击一个音色，将它设为有声书的朗读声音。',
                                  'Available voices are synced from the cloud. Tap one to use it for audiobook reading.',
                                  'クラウドから音声を同期します。音声をタップして読み上げに設定してください。',
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              key: const ValueKey('sync-tts-voices'),
                              onPressed:
                                  capabilities.presetVoices && !_loadingPreset
                                  ? () => _syncPresetVoices(provider.id)
                                  : null,
                              icon: _loadingPreset
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(Icons.cloud_sync_outlined),
                              label: Text(
                                _loadingPreset
                                    ? context.tr(
                                        '正在同步音色',
                                        'Syncing voices',
                                        '音声を同期中',
                                      )
                                    : context.tr(
                                        '同步云端音色',
                                        'Sync cloud voices',
                                        'クラウド音声を同期',
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_feedbackMessage != null) ...[
                    const SizedBox(height: 12),
                    _VoiceFeedbackBanner(
                      message: _feedbackMessage!,
                      isError: _feedbackIsError,
                      onDismiss: () => setState(() => _feedbackMessage = null),
                    ),
                  ],
                  if (widget.guidedSelection) ..._buildVoiceListSection(),
                  if (!widget.guidedSelection && capabilities.voiceCloning) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('克隆音色', 'Clone Voice', '音声をクローン'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _cloneNameController,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: context.tr(
                                  '音色名称',
                                  'Voice name',
                                  '音声名',
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _cloneTextController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: context.tr(
                                  '参考文本',
                                  'Reference transcript',
                                  '参照テキスト',
                                ),
                                hintText: context.tr(
                                  '尽量填写样本音频中实际说出的文字，可显著稳定音色',
                                  'Enter the words spoken in the sample for a more stable voice.',
                                  'サンプル音声で実際に話す言葉を入力すると音声が安定します',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: _cloningVoice ? null : _cloneVoice,
                                icon: _cloningVoice
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(Icons.upload_file_outlined),
                                label: Text(
                                  context.tr(
                                    '选择音频并保存',
                                    'Choose Audio and Save',
                                    '音声を選択して保存',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!widget.guidedSelection &&
                      capabilities.voiceDescription) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('描述生成音色', 'Design a Voice', '音声をデザイン'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: context.tr(
                                  '音色名称',
                                  'Voice name',
                                  '音声名',
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _descriptionController,
                              minLines: 3,
                              maxLines: 5,
                              maxLength: capabilities.maxDescriptionLength,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: context.tr(
                                  '音色描述',
                                  'Voice description',
                                  '音声の説明',
                                ),
                                hintText: context.tr(
                                  '例如：温暖、自然、适合睡前听书的女声',
                                  'For example: a warm, natural female voice for bedtime listening',
                                  '例: 温かく自然な、寝る前の読書に合う女性の声',
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: _creatingVoice
                                    ? null
                                    : _createVoiceFromDescription,
                                icon: _creatingVoice
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(Icons.auto_awesome),
                                label: Text(
                                  context.tr(
                                    '生成并保存',
                                    'Generate and Save',
                                    '生成して保存',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!widget.guidedSelection) ..._buildVoiceListSection(),
                ],
              ),
            ),
          ),
          if (widget.guidedSelection)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SetupNavigationBar(
                  previousLabel: context.tr('上一步', 'Previous', '戻る'),
                  nextLabel: context.tr('完成', 'Finish', '完了'),
                  onPrevious: () => Navigator.of(context).pop(false),
                  onNext: _pendingVoiceId == null && _activeVoiceId == null
                      ? null
                      : _confirmGuidedVoice,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildVoiceListSection() => [
    const SizedBox(height: 20),
    Text(
      widget.guidedSelection
          ? context.tr('选择一个音色', 'Choose a voice', '音声を選択')
          : context.tr('已保存音色', 'Saved Voices', '保存済みの音声'),
      style: Theme.of(context).textTheme.titleMedium,
    ),
    const SizedBox(height: 8),
    FutureBuilder<List<drift_db.Voice>>(
      future: _voicesFuture,
      builder: (context, snapshot) {
        final voices = snapshot.data ?? const <drift_db.Voice>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (voices.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _loadingPreset
                  ? Row(
                      children: [
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.tr(
                              '正在同步云端音色…',
                              'Syncing cloud voices…',
                              'クラウド音声を同期中…',
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      context.tr(
                        '暂无可用音色，请重新同步。',
                        'No voices are available. Try syncing again.',
                        '利用可能な音声がありません。再同期してください。',
                      ),
                    ),
            ),
          );
        }
        return Column(
          children: [
            for (final voice in voices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _VoiceCard(
                  key: ValueKey('voice-option-${voice.id}'),
                  voice: voice,
                  selected: voice.id == _displayedVoiceId,
                  playing: voice.id == _playingVoiceId,
                  guidedSelection: widget.guidedSelection,
                  onPreview: () => _previewVoice(voice),
                  onUse: () => _setActiveVoice(voice.id),
                  onShare: () => _copyVoiceLink(voice),
                  onDelete: () => _deleteVoice(voice.id),
                ),
              ),
          ],
        );
      },
    ),
  ];

  Future<void> _syncPresetVoices(String providerId) async {
    setState(() => _loadingPreset = true);
    try {
      final provider = ref.read(activeTtsProviderProvider);
      final voices = await provider.listPresetVoices();
      final db = ref.read(appDatabaseProvider);
      for (final voice in voices) {
        await db.upsertVoice(_toDbVoice(voice));
      }
      if (!mounted) return;
      _showFeedback(
        context.tr(
          '已同步 ${voices.length} 个 $providerId 音色',
          'Synced ${voices.length} $providerId voices',
          '${voices.length}個の$providerId音声を同期済み',
        ),
      );
      _reloadVoices();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Voice',
        '同步预置音色失败 provider=$providerId',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _showFeedback(
        context.tr('同步音色失败。', 'Unable to sync voices.', '音声の同期に失敗しました。'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loadingPreset = false);
    }
  }

  Future<void> _createVoiceFromDescription() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.isEmpty || description.isEmpty) {
      _showFeedback(
        context.tr(
          '请填写音色名称和描述',
          'Enter a voice name and description',
          '音声名と説明を入力してください',
        ),
        isError: true,
      );
      return;
    }

    setState(() => _creatingVoice = true);
    try {
      final provider = ref.read(activeTtsProviderProvider);
      final voice = await provider.createVoiceFromDescription(
        name: name,
        description: description,
      );
      await ref.read(appDatabaseProvider).upsertVoice(_toDbVoice(voice));
      await ref
          .read(providerSelectionRepositoryProvider)
          .setSelectedVoice(provider.id, voice.id);
      _activeVoiceId = voice.id;
      _nameController.clear();
      _descriptionController.clear();
      if (!mounted) return;
      _showFeedback(
        context.tr(
          '音色已生成并设为当前音色',
          'Voice generated and set as current',
          '音声を生成し、現在の音声に設定しました',
        ),
      );
      _reloadVoices();
    } catch (e, stackTrace) {
      AppLogger.error('Voice', '描述生成音色失败', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      _showFeedback(
        context.tr(
          '音色生成失败。',
          'Unable to generate the voice.',
          '音声を生成できませんでした。',
        ),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _creatingVoice = false);
    }
  }

  Future<void> _cloneVoice() async {
    final name = _cloneNameController.text.trim();
    if (name.isEmpty) {
      _showFeedback(
        context.tr('请填写音色名称', 'Enter a voice name', '音声名を入力してください'),
        isError: true,
      );
      return;
    }

    final provider = ref.read(activeTtsProviderProvider);
    final transcript = _cloneTextController.text.trim();
    final constraints = provider.capabilities.cloneConstraints;
    final allowedExtensions =
        constraints?.allowedFormats
            .map((f) => f.replaceFirst('.', ''))
            .toList() ??
        const ['wav', 'mp3', 'm4a'];

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    if (!mounted) return;

    final file = picked.files.single;
    final filePath = file.path;
    final bytes =
        file.bytes ??
        (filePath == null ? null : await File(filePath).readAsBytes());
    if (bytes == null) {
      if (!mounted) return;
      _showFeedback(
        context.tr(
          '无法读取音频文件',
          'Unable to read the audio file',
          '音声ファイルを読み込めません',
        ),
        isError: true,
      );
      return;
    }
    if (!mounted) return;
    final maxSize = constraints?.maxSizeBytes;
    if (maxSize != null && bytes.length > maxSize) {
      if (!mounted) return;
      _showFeedback(
        context.tr(
          '样本文件过大：最大 ${_formatBytes(maxSize)}',
          'The sample is too large. Maximum: ${_formatBytes(maxSize)}',
          'サンプルが大きすぎます。最大: ${_formatBytes(maxSize)}',
        ),
        isError: true,
      );
      return;
    }

    setState(() => _cloningVoice = true);
    try {
      final extension = (file.extension ?? file.name.split('.').last)
          .toLowerCase();
      final cloned = await provider.cloneVoice(
        audioBytes: bytes,
        format: extension,
        name: name,
        samplePath: file.path,
      );
      final voice = transcript.isEmpty
          ? cloned
          : cloned.copyWith(description: transcript);

      await ref.read(appDatabaseProvider).upsertVoice(_toDbVoice(voice));
      await ref
          .read(providerSelectionRepositoryProvider)
          .setSelectedVoice(provider.id, voice.id);
      _activeVoiceId = voice.id;
      _cloneNameController.clear();
      _cloneTextController.clear();
      if (!mounted) return;
      _showFeedback(
        context.tr(
          '克隆音色已保存并设为当前音色',
          'Cloned voice saved and set as current',
          'クローン音声を保存し、現在の音声に設定しました',
        ),
      );
      _reloadVoices();
    } catch (e, stackTrace) {
      AppLogger.error('Voice', '克隆音色失败', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      _showFeedback(
        context.tr('音色克隆失败。', 'Unable to clone the voice.', '音声のクローンに失敗しました。'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _cloningVoice = false);
    }
  }

  Future<void> _setActiveVoice(String voiceId) async {
    if (widget.guidedSelection) {
      setState(() => _pendingVoiceId = voiceId);
      return;
    }
    final providerId = ref.read(activeTtsProviderProvider).id;
    await ref
        .read(providerSelectionRepositoryProvider)
        .setSelectedVoice(providerId, voiceId);
    ref.invalidate(ttsSettingsControllerProvider);
    if (!mounted) return;
    setState(() => _activeVoiceId = voiceId);
    _showFeedback(
      context.tr('已设为当前音色', 'Set as current voice', '現在の音声に設定しました'),
    );
  }

  String? get _displayedVoiceId => widget.guidedSelection
      ? _pendingVoiceId ?? _activeVoiceId
      : _activeVoiceId;

  Future<void> _confirmGuidedVoice() async {
    final voiceId = _pendingVoiceId ?? _activeVoiceId;
    if (voiceId == null) return;
    final providerId = ref.read(activeTtsProviderProvider).id;
    await ref
        .read(providerSelectionRepositoryProvider)
        .setSelectedVoice(providerId, voiceId);
    ref.invalidate(ttsSettingsControllerProvider);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _loadActiveVoice() async {
    final providerId = ref.read(activeTtsProviderProvider).id;
    final voiceId = await ref
        .read(providerSelectionRepositoryProvider)
        .selectedVoice(providerId);
    if (!mounted) return;
    setState(() {
      _activeVoiceId = voiceId;
      _pendingVoiceId = voiceId;
    });
  }

  Future<void> _deleteVoice(String voiceId) async {
    final db = ref.read(appDatabaseProvider);
    await db.deleteVoice(voiceId);
    if (_activeVoiceId == voiceId) {
      final providerId = ref.read(activeTtsProviderProvider).id;
      await ref
          .read(providerSelectionRepositoryProvider)
          .setSelectedVoice(providerId, null);
      _activeVoiceId = null;
    }
    if (!mounted) return;
    _reloadVoices();
    _showFeedback(context.tr('音色记录已删除', 'Voice record deleted', '音声記録を削除しました'));
  }

  void _reloadVoices() {
    if (!mounted) return;
    final providerId = ref.read(activeTtsProviderProvider).id;
    setState(() {
      _voicesFuture = ref
          .read(appDatabaseProvider)
          .getVoicesByProvider(providerId);
    });
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _feedbackMessage = message;
      _feedbackIsError = isError;
    });
  }

  drift_db.Voice _toDbVoice(TtsVoice voice) {
    return drift_db.Voice(
      id: voice.id,
      name: voice.name,
      providerId: voice.providerId,
      type: voice.type.name,
      providerVoiceId: voice.providerVoiceId,
      samplePath: voice.samplePath,
      description: voice.description,
      presetDescription: voice.presetDescription,
      previewUrl: voice.previewUrl,
      coverUrl: voice.coverUrl,
      languagesJson: jsonEncode(voice.languages),
      sampleCount: voice.sampleCount,
      createdAt: voice.createdAt,
    );
  }

  Future<void> _previewVoice(drift_db.Voice voice) async {
    final noPreviewMessage = context.tr(
      '该音色没有试听片段',
      'No preview is available for this voice.',
      'この音声には試聴サンプルがありません',
    );
    final previewErrorMessage = context.tr(
      '无法播放试听片段',
      'Unable to play this preview.',
      '試聴サンプルを再生できません',
    );
    try {
      if (_playingVoiceId == voice.id) {
        await _previewPlayer.stop();
        if (mounted) setState(() => _playingVoiceId = null);
        return;
      }
      await _previewPlayer.stop();
      final previewUrl = voice.previewUrl?.trim();
      final samplePath = voice.samplePath?.trim();
      if (previewUrl?.isNotEmpty == true) {
        await _previewPlayer.setUrl(previewUrl!);
      } else if (samplePath?.isNotEmpty == true) {
        await _previewPlayer.setFilePath(samplePath!);
      } else {
        final provider = ref
            .read(providerRegistryProvider)
            .get(voice.providerId);
        if (provider == null || voice.providerVoiceId.trim().isEmpty) {
          _showFeedback(noPreviewMessage, isError: true);
          return;
        }
        final chunk = await provider.synthesize(
          text: _previewTextFor(voice),
          voice: _toTtsVoice(voice),
        );
        final directory = await getTemporaryDirectory();
        final extension = chunk.format.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final file = File(
          p.join(
            directory.path,
            'lumina_voice_preview_${voice.id.hashCode}.${extension.isEmpty ? 'wav' : extension}',
          ),
        );
        await file.writeAsBytes(chunk.audioBytes, flush: true);
        _temporaryPreviews.add(file);
        await _previewPlayer.setFilePath(file.path);
      }
      if (mounted) setState(() => _playingVoiceId = voice.id);
      await _previewPlayer.play();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Voice',
        '试听音色失败 voice=${voice.id}',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() => _playingVoiceId = null);
        _showFeedback(previewErrorMessage, isError: true);
      }
    }
  }

  TtsVoice _toTtsVoice(drift_db.Voice voice) => TtsVoice(
    id: voice.id,
    name: voice.name,
    providerId: voice.providerId,
    type: VoiceType.values.byName(voice.type),
    providerVoiceId: voice.providerVoiceId,
    samplePath: voice.samplePath,
    description: voice.description,
    presetDescription: voice.presetDescription,
    previewUrl: voice.previewUrl,
    coverUrl: voice.coverUrl,
    languages: _decodeLanguages(voice.languagesJson),
    sampleCount: voice.sampleCount ?? 0,
    createdAt: voice.createdAt,
  );

  String _previewTextFor(drift_db.Voice voice) {
    final languages = _decodeLanguages(voice.languagesJson);
    final language = languages.isEmpty ? '' : languages.first.toLowerCase();
    if (language.startsWith('zh')) return '你好，这是当前音色的试听片段。';
    if (language.startsWith('ja')) return 'こんにちは、これは現在の音声のプレビューです。';
    return 'Hello, this is a short preview of the selected voice.';
  }

  static List<String> _decodeLanguages(String? value) {
    if (value == null || value.isEmpty) return const [];
    try {
      return (jsonDecode(value) as List<dynamic>).whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _copyVoiceLink(drift_db.Voice voice) async {
    if (voice.providerVoiceId.trim().isEmpty) return;
    final copiedMessage = context.tr(
      '音色链接已复制',
      'Voice link copied',
      '音声リンクをコピーしました',
    );
    await Clipboard.setData(
      ClipboardData(text: 'https://fish.audio/m/${voice.providerVoiceId}'),
    );
    if (mounted) _showFeedback(copiedMessage);
  }

  String _capabilityLine(TtsCapabilities caps) {
    final bits = <String>[];
    bits.add(
      caps.paid
          ? context.tr('按量计费', 'Usage-based', '従量課金')
          : context.tr('免费', 'Free', '無料'),
    );
    if (caps.presetVoices) {
      bits.add(context.tr('预置音色', 'Preset voices', 'プリセット音声'));
    }
    if (caps.voiceCloning) bits.add(context.tr('克隆', 'Cloning', 'クローン'));
    if (caps.voiceDescription) {
      bits.add(context.tr('描述生成', 'Voice design', '音声デザイン'));
    }
    bits.add(
      context.tr(
        '单次上限 ${caps.maxCharsPerCall} 字',
        '${caps.maxCharsPerCall} characters per request',
        '1回${caps.maxCharsPerCall}文字まで',
      ),
    );
    return bits.join(' · ');
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class _VoiceCard extends StatelessWidget {
  final drift_db.Voice voice;
  final bool selected;
  final bool playing;
  final bool guidedSelection;
  final VoidCallback onPreview;
  final VoidCallback onUse;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _VoiceCard({
    super.key,
    required this.voice,
    required this.selected,
    required this.playing,
    required this.guidedSelection,
    required this.onPreview,
    required this.onUse,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languages = _languages;
    final description = voice.presetDescription?.trim();
    final fallbackDescription = selected
        ? '${context.tr('当前音色', 'Current voice', '現在の音声')} · ${voice.type} · ${voice.providerVoiceId}'
        : '${voice.type} · ${voice.providerVoiceId}';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.onSurface.withValues(alpha: 0.16)
              : theme.dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        onTap: onUse,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VoiceArtwork(
                voice: voice,
                playing: playing,
                onPressed: onPreview,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  voice.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (languages.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  _flagFor(languages.first),
                                  style: const TextStyle(fontSize: 17),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(voice.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description?.isNotEmpty == true
                          ? description!
                          : fallbackDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr(
                              '${voice.sampleCount ?? 0} 音频片段',
                              '${voice.sampleCount ?? 0} audio samples',
                              '${voice.sampleCount ?? 0}件の音声サンプル',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: context.appTextSecondary,
                            ),
                          ),
                        ),
                        if (voice.providerVoiceId.trim().isNotEmpty)
                          IconButton(
                            tooltip: context.tr(
                              '复制分享链接',
                              'Copy share link',
                              '共有リンクをコピー',
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: onShare,
                            icon: const Icon(Icons.share_outlined, size: 20),
                          ),
                        if (!guidedSelection)
                          PopupMenuButton<String>(
                            tooltip: context.tr('更多', 'More', 'その他'),
                            onSelected: (value) {
                              if (value == 'delete') onDelete();
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  context.tr(
                                    '删除本地记录',
                                    'Delete local record',
                                    'ローカル記録を削除',
                                  ),
                                ),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert, size: 21),
                          ),
                        const SizedBox(width: 4),
                        FilledButton.icon(
                          onPressed: onUse,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 10,
                            ),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: theme.colorScheme.onSurface,
                            foregroundColor: theme.colorScheme.surface,
                          ),
                          icon: Icon(
                            selected
                                ? Icons.graphic_eq
                                : Icons.multitrack_audio_outlined,
                            size: 18,
                          ),
                          label: Text(
                            selected
                                ? context.tr('使用中', 'Using', '使用中')
                                : context.tr('使用', 'Use', '使用'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> get _languages {
    final value = voice.languagesJson;
    if (value == null || value.isEmpty) return const [];
    try {
      return (jsonDecode(value) as List<dynamic>).whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  static String _flagFor(String language) {
    final normalized = language.toLowerCase();
    if (normalized.startsWith('zh')) return '🇨🇳';
    if (normalized.startsWith('ja')) return '🇯🇵';
    if (normalized.startsWith('ko')) return '🇰🇷';
    if (normalized.startsWith('en')) return '🇺🇸';
    if (normalized.startsWith('fr')) return '🇫🇷';
    if (normalized.startsWith('de')) return '🇩🇪';
    if (normalized.startsWith('es')) return '🇪🇸';
    return '🌐';
  }

  static String _formatDate(int milliseconds) {
    final value = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class _VoiceArtwork extends StatelessWidget {
  final drift_db.Voice voice;
  final bool playing;
  final VoidCallback onPressed;

  const _VoiceArtwork({
    required this.voice,
    required this.playing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = CustomPaint(
      painter: _VoicePatternPainter(seed: voice.providerVoiceId.hashCode),
      size: Size.infinite,
    );
    final coverUrl = voice.coverUrl?.trim();
    return SizedBox.square(
      dimension: 76,
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl?.isNotEmpty == true)
              DiskCachedNetworkImage(
                url: coverUrl!,
                fit: BoxFit.cover,
                placeholder: placeholder,
              )
            else
              placeholder,
            Material(
              color: Colors.black.withValues(alpha: 0.16),
              child: InkWell(
                onTap: onPressed,
                child: Icon(
                  playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoicePatternPainter extends CustomPainter {
  final int seed;

  const _VoicePatternPainter({required this.seed});

  static const _palettes = <List<Color>>[
    [Color(0xFFEFD6CE), Color(0xFFF7EEE9), Color(0xFFD8A79B)],
    [Color(0xFFD7DDD4), Color(0xFFF1F0E8), Color(0xFF9EAF9B)],
    [Color(0xFFD9D4E8), Color(0xFFF4F0F7), Color(0xFFAAA0C7)],
    [Color(0xFFE5D9C7), Color(0xFFF5EFE5), Color(0xFFC0A989)],
    [Color(0xFFCEDFE2), Color(0xFFEEF4F3), Color(0xFF91B4B9)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final palette = _palettes[seed.abs() % _palettes.length];
    canvas.drawRect(Offset.zero & size, Paint()..color = palette[1]);

    final broad = Paint()
      ..color = palette[0]
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.2
      ..strokeCap = StrokeCap.round;
    final fine = Paint()
      ..color = palette[2].withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;
    final shift = (seed.abs() % 17) / 17 * size.width;

    final broadPath = Path()
      ..moveTo(-size.width * 0.3, size.height * 0.28)
      ..cubicTo(
        size.width * 0.12 + shift * 0.08,
        size.height * 0.02,
        size.width * 0.45,
        size.height * 0.78,
        size.width * 1.3,
        size.height * 0.42,
      );
    canvas.drawPath(broadPath, broad);

    for (var index = 0; index < 3; index++) {
      final y = size.height * (0.25 + index * 0.22);
      final path = Path()
        ..moveTo(-size.width * 0.15, y)
        ..cubicTo(
          size.width * 0.22,
          y - size.height * 0.18,
          size.width * 0.62,
          y + size.height * 0.2,
          size.width * 1.15,
          y - size.height * 0.04,
        );
      canvas.drawPath(path, fine);
    }
  }

  @override
  bool shouldRepaint(covariant _VoicePatternPainter oldDelegate) =>
      oldDelegate.seed != seed;
}

class _VoiceFeedbackBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _VoiceFeedbackBanner({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final color = isError ? Colors.redAccent : accent;
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: TextStyle(color: color)),
            ),
            IconButton(
              tooltip: '关闭',
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
