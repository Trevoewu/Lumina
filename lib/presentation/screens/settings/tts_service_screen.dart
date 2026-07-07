import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/service_settings_controllers.dart';
import '../../../services/kokoro_model_manager.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/providers/fish_audio_api_tts_provider.dart';
import '../../../tts/providers/fish_audio_local_tts_provider.dart';
import '../../../tts/providers/kokoro_local_tts_provider.dart';
import '../../../tts/providers/minimax_tts_provider.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/app_section_header.dart';
import '../../widgets/design_system/settings_components.dart';
import 'voice_library_screen.dart';

class TtsServiceScreen extends ConsumerWidget {
  const TtsServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final state = ref.watch(ttsSettingsControllerProvider);
    return CollapsingPageScaffold(
      title: context.tr('文本转语音', 'Text to Speech'),
      showBackButton: true,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SettingsErrorState(
          error: error,
          onRetry: () => ref.invalidate(ttsSettingsControllerProvider),
        ),
        data: (data) => ListView(
          padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
          children: [
            ServiceStatusCard(
              icon: Icons.record_voice_over_outlined,
              title: context.tr('当前语音服务', 'Current voice service'),
              provider: data.providerName ?? context.tr('未选择服务', 'No provider'),
              selection: data.voiceName ?? context.tr('未选择音色', 'No voice'),
              readiness: data.readiness,
              onTap: () {},
            ),
            if (data.notice != null) ...[
              SizedBox(height: design.spaceMd),
              SettingsFeedbackBanner(message: data.notice!.message),
            ],
            AppSectionHeader(title: context.tr('配置', 'Configuration')),
            SettingsGroup(
              children: [
                SettingValueRow(
                  icon: Icons.hub_outlined,
                  title: context.tr('语音服务', 'Provider'),
                  value: data.providerName ?? context.tr('未选择', 'Not selected'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TtsProviderPickerScreen(),
                    ),
                  ),
                ),
                SettingValueRow(
                  icon: Icons.voice_chat_outlined,
                  title: context.tr('音色', 'Voice'),
                  value: data.voiceName ?? context.tr('未选择', 'Not selected'),
                  onTap: data.providerId == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const VoiceLibraryScreen(),
                          ),
                        ),
                ),
                if (data.providerId != null)
                  SettingValueRow(
                    icon: Icons.tune,
                    title: context.tr('服务详情', 'Provider details'),
                    subtitle: context.tr(
                      '凭据、模型与连接测试',
                      'Credentials, model, and connection test',
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TtsProviderDetailsScreen(
                          providerId: data.providerId!,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TtsProviderPickerScreen extends ConsumerWidget {
  const TtsProviderPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ttsSettingsControllerProvider);
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return CollapsingPageScaffold(
      title: context.tr('语音服务', 'Voice Provider'),
      showBackButton: true,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SettingsErrorState(
          error: error,
          onRetry: () => ref.invalidate(ttsSettingsControllerProvider),
        ),
        data: (data) => ListView(
          padding: EdgeInsets.fromLTRB(
            inset,
            design.spaceSm,
            inset,
            design.spaceXl,
          ),
          children: [
            SettingsGroup(
              children: [
                for (final provider in data.providers)
                  ProviderOptionTile(
                    provider: provider,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TtsProviderDetailsScreen(providerId: provider.id),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TtsProviderDetailsScreen extends ConsumerStatefulWidget {
  final String providerId;

  const TtsProviderDetailsScreen({super.key, required this.providerId});

  @override
  ConsumerState<TtsProviderDetailsScreen> createState() =>
      _TtsProviderDetailsScreenState();
}

class _TtsProviderDetailsScreenState
    extends ConsumerState<TtsProviderDetailsScreen> {
  final _apiKeyController = TextEditingController();
  bool _saving = false;
  bool _testing = false;
  bool _providerReady = false;
  String? _feedback;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(providerRegistryProvider).get(widget.providerId);
    if (provider == null) {
      return Scaffold(
        body: SettingsEmptyState(
          icon: Icons.error_outline,
          message: 'Provider no longer exists.',
          actionLabel: 'Back',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final activeId = ref.watch(activeTtsProviderIdProvider);
    final manager = switch (provider.id) {
      KokoroLocalTtsProvider.idValue =>
        ref.watch(kokoroModelManagerProvider) as LocalTtsModelManager,
      FishAudioLocalTtsProvider.idValue =>
        ref.watch(fishAudioModelManagerProvider) as LocalTtsModelManager,
      _ => null,
    };
    return CollapsingPageScaffold(
      title: provider.displayName,
      showBackButton: true,
      body: ListView(
        padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
        children: [
          if (_feedback != null) ...[
            SettingsFeedbackBanner(message: _feedback!),
            SizedBox(height: design.spaceMd),
          ],
          AppSectionHeader(title: context.tr('连接', 'Connection')),
          SettingsGroup(
            children: [
              if (provider is MinimaxTtsProvider ||
                  provider is FishAudioApiTtsProvider)
                Padding(
                  padding: EdgeInsets.all(design.spaceLg),
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'API Key'),
                  ),
                ),
              if (provider is FishAudioApiTtsProvider)
                FutureBuilder<FishAudioGenerationProfile>(
                  future: provider.generationProfile,
                  builder: (context, snapshot) => Padding(
                    padding: EdgeInsets.all(design.spaceLg),
                    child: SegmentedButton<FishAudioGenerationProfile>(
                      segments: const [
                        ButtonSegment(
                          value: FishAudioGenerationProfile.fast,
                          label: Text('Fast'),
                        ),
                        ButtonSegment(
                          value: FishAudioGenerationProfile.quality,
                          label: Text('Quality'),
                        ),
                      ],
                      selected: {
                        snapshot.data ?? FishAudioGenerationProfile.fast,
                      },
                      onSelectionChanged: (value) =>
                          provider.setGenerationProfile(value.single),
                    ),
                  ),
                ),
              if (manager != null) _LocalModelRow(manager: manager),
              if (manager == null &&
                  provider is! MinimaxTtsProvider &&
                  provider is! FishAudioApiTtsProvider)
                SettingValueRow(
                  icon: Icons.check_circle_outline,
                  title: context.tr('无需额外配置', 'No additional setup'),
                ),
            ],
          ),
          SizedBox(height: design.spaceXl),
          if (provider is MinimaxTtsProvider ||
              provider is FishAudioApiTtsProvider)
            FilledButton.icon(
              onPressed: _saving ? null : () => _saveKey(provider),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(context.tr('保存凭据', 'Save credentials')),
            ),
          SizedBox(height: design.spaceMd),
          OutlinedButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering_outlined),
            label: Text(context.tr('测试服务', 'Test provider')),
          ),
          SizedBox(height: design.spaceMd),
          FilledButton(
            onPressed: activeId == provider.id || !_providerReady
                ? null
                : () => _activate(provider.id),
            child: Text(
              activeId == provider.id
                  ? context.tr('当前服务', 'Current provider')
                  : context.tr('设为当前服务', 'Use this provider'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveKey(Object provider) async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;
    setState(() => _saving = true);
    if (provider is MinimaxTtsProvider) {
      await provider.setApiKey(key);
    }
    if (provider is FishAudioApiTtsProvider) {
      await provider.setApiKey(key);
    }
    _apiKeyController.clear();
    if (mounted) {
      setState(() {
        _saving = false;
        _feedback = 'Credentials saved.';
      });
    }
    ref.invalidate(ttsSettingsControllerProvider);
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    final valid = await ref
        .read(providerRegistryProvider)
        .get(widget.providerId)!
        .validate();
    if (mounted) {
      setState(() {
        _testing = false;
        _providerReady = valid;
        _feedback = valid ? 'Connection succeeded.' : 'Provider is not ready.';
      });
    }
    ref.invalidate(ttsSettingsControllerProvider);
  }

  Future<void> _activate(String providerId) async {
    await ref
        .read(ttsSettingsControllerProvider.notifier)
        .selectProvider(providerId);
    if (mounted) Navigator.of(context).pop();
  }
}

class _LocalModelRow extends StatelessWidget {
  final LocalTtsModelManager manager;

  const _LocalModelRow({required this.manager});

  @override
  Widget build(BuildContext context) => StreamBuilder<KokoroModelStatus>(
    stream: manager.statusStream,
    initialData: manager.status,
    builder: (context, snapshot) {
      final status = snapshot.data ?? manager.status;
      return SettingValueRow(
        icon: Icons.download_for_offline_outlined,
        title: manager.displayName,
        subtitle: status.message,
        value: status.isInstalled
            ? 'Installed'
            : status.isDownloading
            ? '${(status.progress * 100).round()}%'
            : 'Not installed',
        trailing: status.isDownloading
            ? IconButton(
                onPressed: manager.cancel,
                icon: const Icon(Icons.close),
              )
            : IconButton(
                onPressed: status.isInstalled
                    ? manager.redownload
                    : manager.download,
                icon: const Icon(Icons.download_outlined),
              ),
      );
    },
  );
}
