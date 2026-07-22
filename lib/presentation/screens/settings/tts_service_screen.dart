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

class TtsProviderPickerScreen extends ConsumerStatefulWidget {
  const TtsProviderPickerScreen({super.key});

  @override
  ConsumerState<TtsProviderPickerScreen> createState() =>
      _TtsProviderPickerScreenState();
}

class _TtsProviderPickerScreenState
    extends ConsumerState<TtsProviderPickerScreen> {
  String? _switchingProviderId;
  String? _feedback;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ttsSettingsControllerProvider);
    final registry = ref.watch(providerRegistryProvider);
    final configurationStatus = ref.watch(
      ttsProviderConfigurationStatusProvider,
    );
    final configuredById = configurationStatus.when(
      data: (value) => value,
      error: (_, _) => const <String, bool>{},
      loading: () => const <String, bool>{},
    );
    final checkingConfiguration =
        configurationStatus is AsyncLoading<Map<String, bool>>;
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return CollapsingPageScaffold(
      title: context.tr('管理语音服务', 'Manage Voice Providers'),
      showBackButton: true,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SettingsErrorState(
          error: error,
          onRetry: () => ref.invalidate(ttsSettingsControllerProvider),
        ),
        data: (data) {
          final current = data.providers
              .where((provider) => provider.active)
              .toList();
          final available = data.providers
              .where((provider) => !provider.active)
              .toList();
          return ListView(
            padding: EdgeInsets.fromLTRB(
              inset,
              design.spaceMd,
              inset,
              design.spaceXl,
            ),
            children: [
              Text(
                context.tr(
                  '已配置的服务可直接切换；其他服务需要先完成设置。',
                  'Switch configured providers directly, or set up a new one first.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (_feedback != null) ...[
                SizedBox(height: design.spaceMd),
                SettingsFeedbackBanner(message: _feedback!, error: true),
              ],
              if (current.isNotEmpty) ...[
                AppSectionHeader(
                  title: context.tr('当前使用', 'Current'),
                  padding: EdgeInsets.only(
                    top: design.spaceXl,
                    bottom: design.spaceSm,
                  ),
                ),
                SettingsGroup(
                  children: [
                    for (final provider in current)
                      _TtsProviderTile(
                        provider: provider,
                        requiresNetwork:
                            registry
                                .get(provider.id)
                                ?.capabilities
                                .requiresNetwork ??
                            true,
                        current: true,
                        switching: false,
                        configured: configuredById[provider.id] ?? false,
                        checkingConfiguration: checkingConfiguration,
                        onUse: null,
                        onDetails: () => _openDetails(provider.id),
                      ),
                  ],
                ),
              ],
              if (available.isNotEmpty) ...[
                AppSectionHeader(title: context.tr('其他服务', 'Other providers')),
                SettingsGroup(
                  children: [
                    for (final provider in available)
                      _TtsProviderTile(
                        provider: provider,
                        requiresNetwork:
                            registry
                                .get(provider.id)
                                ?.capabilities
                                .requiresNetwork ??
                            true,
                        current: false,
                        switching: _switchingProviderId == provider.id,
                        configured: configuredById[provider.id] ?? false,
                        checkingConfiguration: checkingConfiguration,
                        onUse: configuredById[provider.id] == true
                            ? () => _useProvider(provider.id)
                            : null,
                        onDetails: () => _openDetails(provider.id),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openDetails(String providerId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TtsProviderDetailsScreen(providerId: providerId),
      ),
    );
    ref.invalidate(ttsProviderConfigurationStatusProvider);
  }

  Future<void> _useProvider(String providerId) async {
    if (_switchingProviderId != null) return;
    setState(() {
      _switchingProviderId = providerId;
      _feedback = null;
    });
    try {
      await ref
          .read(ttsSettingsControllerProvider.notifier)
          .selectProvider(providerId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _switchingProviderId = null;
        _feedback = context.tr(
          '无法切换服务，请打开详情检查凭据或模型配置。',
          'Could not switch providers. Open details to check credentials or model setup.',
        );
      });
    }
  }
}

class _TtsProviderTile extends StatelessWidget {
  final ProviderOptionViewData provider;
  final bool requiresNetwork;
  final bool current;
  final bool switching;
  final bool configured;
  final bool checkingConfiguration;
  final VoidCallback? onUse;
  final VoidCallback onDetails;

  const _TtsProviderTile({
    required this.provider,
    required this.requiresNetwork,
    required this.current,
    required this.switching,
    required this.configured,
    required this.checkingConfiguration,
    required this.onUse,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final scheme = Theme.of(context).colorScheme;
    final status = current
        ? context.tr('当前使用', 'In use')
        : checkingConfiguration
        ? context.tr('正在检查', 'Checking')
        : configured
        ? context.tr('已配置', 'Configured')
        : requiresNetwork
        ? context.tr('需要 API Key', 'API key required')
        : context.tr('需要安装模型', 'Model required');
    final statusColor = current || configured
        ? scheme.primary
        : scheme.onSurfaceVariant;
    return ListTile(
      key: ValueKey('provider-${provider.id}'),
      minTileHeight: design.toolbarHeight + design.spaceMd,
      contentPadding: EdgeInsets.only(
        left: design.spaceLg,
        right: design.spaceSm,
        top: design.spaceXs,
        bottom: design.spaceXs,
      ),
      leading: CircleAvatar(
        backgroundColor:
            (current ? scheme.primary : scheme.surfaceContainerHighest)
                .withValues(alpha: current ? 0.14 : 0.75),
        foregroundColor: current ? scheme.primary : scheme.onSurfaceVariant,
        child: Icon(
          requiresNetwork ? Icons.cloud_outlined : Icons.memory_outlined,
        ),
      ),
      title: Text(
        provider.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: provider.subtitle),
            const TextSpan(text: ' · '),
            TextSpan(
              text: status,
              style: TextStyle(color: statusColor),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: current
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: scheme.primary),
                IconButton(
                  tooltip: context.tr('服务详情', 'Provider details'),
                  onPressed: onDetails,
                  icon: const Icon(Icons.info_outline),
                ),
              ],
            )
          : switching
          ? Padding(
              padding: EdgeInsets.symmetric(horizontal: design.spaceMd),
              child: const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : checkingConfiguration
          ? Padding(
              padding: EdgeInsets.symmetric(horizontal: design.spaceMd),
              child: const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : configured
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: onUse,
                  child: Text(context.tr('使用', 'Use')),
                ),
                IconButton(
                  tooltip: context.tr('服务详情', 'Provider details'),
                  onPressed: onDetails,
                  icon: const Icon(Icons.info_outline),
                ),
              ],
            )
          : TextButton(
              onPressed: onDetails,
              child: Text(context.tr('设置', 'Set up')),
            ),
      onTap: current
          ? null
          : checkingConfiguration
          ? onDetails
          : configured
          ? onUse
          : onDetails,
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
  bool _activating = false;
  String? _feedback;
  bool _feedbackIsError = false;

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
            SettingsFeedbackBanner(
              message: _feedback!,
              error: _feedbackIsError,
            ),
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
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      helperText: context.tr(
                        '已保存的凭据不会在此处显示',
                        'Saved credentials are never shown here',
                      ),
                    ),
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
          FilledButton.icon(
            onPressed: activeId == provider.id || _activating
                ? null
                : () => _activate(provider.id),
            icon: _activating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    activeId == provider.id
                        ? Icons.check
                        : Icons.check_circle_outline,
                  ),
            label: Text(
              activeId == provider.id
                  ? context.tr('当前服务', 'Current provider')
                  : context.tr('设为当前服务', 'Use this provider'),
            ),
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
        _feedback = context.tr('凭据已保存。', 'Credentials saved.');
        _feedbackIsError = false;
      });
    }
    ref.invalidate(ttsSettingsControllerProvider);
    ref.invalidate(ttsProviderConfigurationStatusProvider);
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
        _feedback = valid
            ? context.tr('连接成功。', 'Connection succeeded.')
            : context.tr('服务尚未就绪，请检查配置。', 'Provider is not ready.');
        _feedbackIsError = !valid;
      });
    }
    ref.invalidate(ttsSettingsControllerProvider);
  }

  Future<void> _activate(String providerId) async {
    setState(() {
      _activating = true;
      _feedback = null;
      _feedbackIsError = false;
    });
    try {
      await ref
          .read(ttsSettingsControllerProvider.notifier)
          .selectProvider(providerId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activating = false;
        _feedback = context.tr(
          '无法使用此服务，请检查凭据、模型或网络连接。',
          'Could not use this provider. Check credentials, model setup, or your connection.',
        );
        _feedbackIsError = true;
      });
    }
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
