import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../tts/models/tts_capabilities.dart';
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/providers/fish_audio_local_tts_provider.dart';

class VoiceLibraryScreen extends ConsumerStatefulWidget {
  const VoiceLibraryScreen({super.key});

  @override
  ConsumerState<VoiceLibraryScreen> createState() => _VoiceLibraryScreenState();
}

class _VoiceLibraryScreenState extends ConsumerState<VoiceLibraryScreen> {
  bool _loadingPreset = false;
  bool _creatingVoice = false;
  bool _cloningVoice = false;
  final _descriptionController = TextEditingController();
  final _nameController = TextEditingController();
  final _cloneNameController = TextEditingController();
  final _cloneTextController = TextEditingController();

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
    final db = ref.watch(appDatabaseProvider);
    final provider = ref.watch(activeTtsProviderProvider);
    final capabilities = provider.capabilities;

    return Scaffold(
      appBar: AppBar(title: const Text('音色库')),
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
                        const Icon(Icons.record_voice_over_outlined),
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
                          : const Icon(Icons.cloud_sync_outlined),
                      label: const Text('同步当前 Provider 预置音色'),
                    ),
                  ],
                ),
              ),
            ),
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
                              : const Icon(Icons.upload_file_outlined),
                          label: const Text('选择音频并保存'),
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
                              : const Icon(Icons.auto_awesome),
                          label: const Text('生成并保存'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('已保存音色', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<drift_db.Voice>>(
              future: db.getVoicesByProvider(provider.id),
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
                          leading: Icon(_iconForType(voice.type)),
                          title: Text(voice.name),
                          subtitle: Text(
                            '${voice.providerId} · ${voice.type} · ${voice.providerVoiceId}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: '删除本地记录',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await db.deleteVoice(voice.id);
                              if (mounted) setState(() {});
                            },
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      final provider = ref.read(activeTtsProviderProvider);
      final voices = await provider.listPresetVoices();
      final db = ref.read(appDatabaseProvider);
      for (final voice in voices) {
        await db.upsertVoice(_toDbVoice(voice));
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('已同步 ${voices.length} 个 $providerId 音色')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('同步失败：$e')));
    } finally {
      if (mounted) setState(() => _loadingPreset = false);
    }
  }

  Future<void> _createVoiceFromDescription() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写音色名称和描述')));
      return;
    }

    setState(() => _creatingVoice = true);
    final messenger = ScaffoldMessenger.of(context);
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
      _nameController.clear();
      _descriptionController.clear();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('音色已生成并保存')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('生成失败：$e')));
    } finally {
      if (mounted) setState(() => _creatingVoice = false);
    }
  }

  Future<void> _cloneVoice() async {
    final name = _cloneNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写音色名称')));
      return;
    }

    final provider = ref.read(activeTtsProviderProvider);
    final transcript = _cloneTextController.text.trim();
    if (provider.id == FishAudioLocalTtsProvider.idValue &&
        transcript.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fish Audio 克隆音色必须填写参考文本')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法读取音频文件')));
      return;
    }
    if (!mounted) return;
    final maxSize = constraints?.maxSizeBytes;
    if (maxSize != null && bytes.length > maxSize) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('样本文件过大：最大 ${_formatBytes(maxSize)}')),
      );
      return;
    }

    setState(() => _cloningVoice = true);
    final messenger = ScaffoldMessenger.of(context);
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
      _cloneNameController.clear();
      _cloneTextController.clear();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('克隆音色已保存并设为当前音色')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('克隆失败：$e')));
    } finally {
      if (mounted) setState(() => _cloningVoice = false);
    }
  }

  Future<void> _setActiveVoice(String voiceId) async {
    await ref.read(appDatabaseProvider).setSetting('active_voice_id', voiceId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已设为当前音色')));
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
