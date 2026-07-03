import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../services/app_log_service.dart';
import '../../../tts/models/tts_capabilities.dart';
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/providers/fish_audio_local_tts_provider.dart';
import '../../widgets/collapsing_page_scaffold.dart';

class VoiceLibraryScreen extends ConsumerStatefulWidget {
  const VoiceLibraryScreen({super.key});

  @override
  ConsumerState<VoiceLibraryScreen> createState() => _VoiceLibraryScreenState();
}

class _VoiceLibraryScreenState extends ConsumerState<VoiceLibraryScreen> {
  bool _loadingPreset = false;
  bool _creatingVoice = false;
  bool _cloningVoice = false;
  String? _activeVoiceId;
  String? _feedbackMessage;
  bool _feedbackIsError = false;
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
  }

  @override
  void dispose() {
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
      title: context.tr('音色库', 'Voice Library'),
      showBackButton: true,
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_capabilityLine(provider.capabilities)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: capabilities.presetVoices && !_loadingPreset
                          ? () => _syncPresetVoices(provider.id)
                          : null,
                      icon: _loadingPreset
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.cloud_sync_outlined),
                      label: Text(
                        context.tr(
                          '同步当前 Provider 预置音色',
                          'Sync Provider Preset Voices',
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
            if (capabilities.voiceCloning) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '克隆音色',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cloneNameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '音色名称',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cloneTextController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '参考文本',
                          hintText: '尽量填写样本音频中实际说出的文字，可显著稳定音色',
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
                          label: Text('选择音频并保存'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (capabilities.voiceDescription) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '描述生成音色',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '音色名称',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: capabilities.maxDescriptionLength,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '音色描述',
                          hintText: '例如：温暖、自然、适合睡前听书的女声',
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
                          label: Text('生成并保存'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              context.tr('已保存音色', 'Saved Voices'),
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
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('暂无保存音色。可以先同步预置音色。'),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final voice in voices)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            _iconForType(voice.type),
                            color: voice.id == _activeVoiceId
                                ? Theme.of(context).colorScheme.primary
                                : context.appTextSecondary,
                          ),
                          title: Text(voice.name),
                          subtitle: Text(
                            voice.id == _activeVoiceId
                                ? '当前音色 · ${voice.type} · ${voice.providerVoiceId}'
                                : '${voice.type} · ${voice.providerVoiceId}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (voice.id == _activeVoiceId)
                                Tooltip(
                                  message: '当前音色',
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              IconButton(
                                tooltip: '删除本地记录',
                                icon: Icon(Icons.delete_outline),
                                onPressed: () => _deleteVoice(voice.id),
                              ),
                            ],
                          ),
                          onTap: () => _setActiveVoice(voice.id),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

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
      _showFeedback('已同步 ${voices.length} 个 $providerId 音色');
      _reloadVoices();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Voice',
        '同步预置音色失败 provider=$providerId',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _showFeedback('同步失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _loadingPreset = false);
    }
  }

  Future<void> _createVoiceFromDescription() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.isEmpty || description.isEmpty) {
      _showFeedback('请填写音色名称和描述', isError: true);
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
          .read(appDatabaseProvider)
          .setSetting('active_voice_id', voice.id);
      _activeVoiceId = voice.id;
      _nameController.clear();
      _descriptionController.clear();
      if (!mounted) return;
      _showFeedback('音色已生成并设为当前音色');
      _reloadVoices();
    } catch (e, stackTrace) {
      AppLogger.error('Voice', '描述生成音色失败', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      _showFeedback('生成失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _creatingVoice = false);
    }
  }

  Future<void> _cloneVoice() async {
    final name = _cloneNameController.text.trim();
    if (name.isEmpty) {
      _showFeedback('请填写音色名称', isError: true);
      return;
    }

    final provider = ref.read(activeTtsProviderProvider);
    final transcript = _cloneTextController.text.trim();
    if (provider.id == FishAudioLocalTtsProvider.idValue &&
        transcript.isEmpty) {
      _showFeedback('Fish Audio 克隆音色必须填写参考文本', isError: true);
      return;
    }
    final constraints = provider.capabilities.cloneConstraints;
    final allowedExtensions =
        constraints?.allowedFormats
            .map((f) => f.replaceFirst('.', ''))
            .toList() ??
        const ['wav', 'mp3', 'm4a'];

    final picked = await FilePicker.pickFiles(
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
      _showFeedback('无法读取音频文件', isError: true);
      return;
    }
    if (!mounted) return;
    final maxSize = constraints?.maxSizeBytes;
    if (maxSize != null && bytes.length > maxSize) {
      if (!mounted) return;
      _showFeedback('样本文件过大：最大 ${_formatBytes(maxSize)}', isError: true);
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
          .read(appDatabaseProvider)
          .setSetting('active_voice_id', voice.id);
      _activeVoiceId = voice.id;
      _cloneNameController.clear();
      _cloneTextController.clear();
      if (!mounted) return;
      _showFeedback('克隆音色已保存并设为当前音色');
      _reloadVoices();
    } catch (e, stackTrace) {
      AppLogger.error('Voice', '克隆音色失败', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      _showFeedback('克隆失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _cloningVoice = false);
    }
  }

  Future<void> _setActiveVoice(String voiceId) async {
    await ref.read(appDatabaseProvider).setSetting('active_voice_id', voiceId);
    if (!mounted) return;
    setState(() => _activeVoiceId = voiceId);
    _showFeedback('已设为当前音色');
  }

  Future<void> _loadActiveVoice() async {
    final voiceId = await ref
        .read(appDatabaseProvider)
        .getSetting('active_voice_id');
    if (!mounted) return;
    setState(() => _activeVoiceId = voiceId);
  }

  Future<void> _deleteVoice(String voiceId) async {
    final db = ref.read(appDatabaseProvider);
    await db.deleteVoice(voiceId);
    if (_activeVoiceId == voiceId) {
      await db.setSetting('active_voice_id', '');
      _activeVoiceId = null;
    }
    if (!mounted) return;
    _reloadVoices();
    _showFeedback('音色记录已删除');
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
      createdAt: voice.createdAt,
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'clone' => Icons.person_pin_circle_outlined,
      'description' => Icons.auto_awesome,
      _ => Icons.record_voice_over_outlined,
    };
  }

  String _capabilityLine(TtsCapabilities caps) {
    final bits = <String>[];
    bits.add(caps.paid ? '按量计费' : '免费');
    if (caps.presetVoices) bits.add('预置音色');
    if (caps.voiceCloning) bits.add('克隆');
    if (caps.voiceDescription) bits.add('描述生成');
    bits.add('单次上限 ${caps.maxCharsPerCall} 字');
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
