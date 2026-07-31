import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/service_settings_controllers.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/providers/fish_audio_api_tts_provider.dart';
import '../../../tts/providers/minimax_tts_provider.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/app_section_header.dart';
import '../../widgets/design_system/settings_components.dart';
import 'voice_library_screen.dart';

class TtsServiceScreen extends ConsumerWidget {
  final bool returnWhenReady;

  const TtsServiceScreen({super.key, this.returnWhenReady = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final state = ref.watch(ttsSettingsControllerProvider);
    final providerConfiguration = ref.watch(
      ttsProviderConfigurationStatusProvider,
    );
    return CollapsingPageScaffold(
      title: context.tr('文本转语音', 'Text to Speech'),
      showBackButton: true,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SettingsErrorState(
          error: error,
          onRetry: () => ref.invalidate(ttsSettingsControllerProvider),
        ),
        data: (data) {
          final providerConfigured =
              data.providerId != null &&
              providerConfiguration.asData?.value[data.providerId] == true;
          return ListView(
            padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
            children: [
              ServiceStatusCard(
                icon: Icons.record_voice_over_outlined,
                title: context.tr('当前语音服务', 'Current voice service'),
                provider:
                    data.providerName ?? context.tr('未选择服务', 'No provider'),
                selection: data.voiceName ?? context.tr('未选择音色', 'No voice'),
                readiness: data.readiness,
                onTap: () {},
              ),
              if (data.notice != null) ...[
                SizedBox(height: design.spaceMd),
                SettingsFeedbackBanner(message: data.notice!.message),
              ],
              if (data.readiness != ServiceReadiness.ready) ...[
                SizedBox(height: design.spaceMd),
                SettingsFeedbackBanner(
                  message: providerConfigured && data.voiceId == null
                      ? context.tr(
                          '语音服务已连接。下一步同步并选择朗读音色。',
                          'The voice provider is connected. Next, sync and choose a reading voice.',
                        )
                      : context.tr(
                          '添加并连接云端语音服务，再选择朗读音色，即可生成有声书。',
                          'Connect a cloud voice provider, then choose a reading voice to generate audiobook audio.',
                        ),
                ),
              ],
              AppSectionHeader(title: context.tr('配置', 'Configuration')),
              SettingsGroup(
                children: [
                  SettingValueRow(
                    icon: Icons.hub_outlined,
                    title: context.tr('语音服务', 'Provider'),
                    value:
                        data.providerName ?? context.tr('未选择', 'Not selected'),
                    onTap: () => _openProviders(context, ref),
                  ),
                  SettingValueRow(
                    icon: Icons.voice_chat_outlined,
                    title: context.tr('朗读音色', 'Reading voice'),
                    subtitle: data.voiceId == null
                        ? context.tr(
                            '自动同步云端音色并选择',
                            'Sync cloud voices and choose one',
                          )
                        : context.tr(
                            '更换有声书的朗读声音',
                            'Change the audiobook reading voice',
                          ),
                    value: data.voiceName ?? context.tr('未选择', 'Not selected'),
                    onTap: !providerConfigured
                        ? null
                        : () => _openVoices(
                            context,
                            ref,
                            guidedSelection: data.voiceId == null,
                          ),
                  ),
                  if (data.providerId != null)
                    SettingValueRow(
                      icon: Icons.tune,
                      title: context.tr('服务详情', 'Provider details'),
                      subtitle: context.tr(
                        '凭据与连接测试',
                        'Credentials and connection test',
                      ),
                      onTap: () => _openDetails(
                        context,
                        ref,
                        data.providerId!,
                        adding: data.readiness != ServiceReadiness.ready,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openVoices(
    BuildContext context,
    WidgetRef ref, {
    required bool guidedSelection,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VoiceLibraryScreen(
          guidedSelection: guidedSelection,
          syncOnOpen: guidedSelection,
        ),
      ),
    );
    ref.invalidate(ttsSettingsControllerProvider);
  }

  Future<void> _openProviders(BuildContext context, WidgetRef ref) async {
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TtsProviderPickerScreen()),
    );
    ref.invalidate(ttsSettingsControllerProvider);
    if (connected == true && returnWhenReady && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openDetails(
    BuildContext context,
    WidgetRef ref,
    String providerId, {
    required bool adding,
  }) async {
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            TtsProviderDetailsScreen(providerId: providerId, adding: adding),
      ),
    );
    ref.invalidate(ttsSettingsControllerProvider);
    if (connected == true && returnWhenReady && context.mounted) {
      Navigator.of(context).pop(true);
    }
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
      title: context.tr('语音服务', 'Voice Providers'),
      showBackButton: true,
      actions: [
        IconButton(
          key: const ValueKey('add-tts-provider'),
          tooltip: context.tr('添加语音服务', 'Add voice provider'),
          onPressed: checkingConfiguration ? null : _addProvider,
          icon: const Icon(Icons.add),
        ),
      ],
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => SettingsErrorState(
          error: error,
          onRetry: () => ref.invalidate(ttsSettingsControllerProvider),
        ),
        data: (data) {
          final current = data.providers
              .where(
                (provider) =>
                    provider.active && configuredById[provider.id] == true,
              )
              .toList();
          final available = data.providers
              .where(
                (provider) =>
                    !provider.active && configuredById[provider.id] == true,
              )
              .toList();
          if (!checkingConfiguration && current.isEmpty && available.isEmpty) {
            return SettingsEmptyState(
              icon: Icons.cloud_outlined,
              message: context.tr('尚未添加云端语音服务', 'No cloud voice providers yet'),
              actionLabel: context.tr('添加服务', 'Add provider'),
              onAction: _addProvider,
            );
          }
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
                  '添加云端服务并验证 API Key。连接成功后可随时切换。',
                  'Add a cloud provider and verify its API key. Connected providers can be switched at any time.',
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
                        requiresNetwork: true,
                        current: true,
                        switching: false,
                        configured: true,
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
                        requiresNetwork: true,
                        current: false,
                        switching: _switchingProviderId == provider.id,
                        configured: true,
                        checkingConfiguration: checkingConfiguration,
                        onUse: () => _useProvider(provider.id),
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

  Future<void> _addProvider() async {
    final providerId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.graphic_eq_rounded),
              title: const Text('Fish Audio'),
              subtitle: Text(
                context.tr(
                  '自然语音、声音克隆与流式合成',
                  'Natural voices, voice cloning, and streaming synthesis',
                ),
              ),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(FishAudioApiTtsProvider.idValue),
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over_outlined),
              title: const Text('MiniMax'),
              subtitle: Text(
                context.tr(
                  '高质量语音、声音克隆与声音设计',
                  'High-quality speech, cloning, and voice design',
                ),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(MinimaxTtsProvider.idValue),
            ),
          ],
        ),
      ),
    );
    if (providerId == null || !mounted) return;
    final configuration = await ref.read(
      ttsProviderConfigurationStatusProvider.future,
    );
    final configured = configuration[providerId] == true;
    if (!mounted) return;
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TtsProviderDetailsScreen(
          providerId: providerId,
          adding: !configured,
        ),
      ),
    );
    ref.invalidate(ttsProviderConfigurationStatusProvider);
    ref.invalidate(ttsSettingsControllerProvider);
    if (connected == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _openDetails(String providerId) async {
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TtsProviderDetailsScreen(providerId: providerId),
      ),
    );
    ref.invalidate(ttsProviderConfigurationStatusProvider);
    ref.invalidate(ttsSettingsControllerProvider);
    if (connected == true && mounted) Navigator.of(context).pop(true);
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
      final selectedVoiceId = await ref
          .read(providerSelectionRepositoryProvider)
          .selectedVoice(providerId);
      if (selectedVoiceId == null && mounted) {
        final selected = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const VoiceLibraryScreen(
              guidedSelection: true,
              syncOnOpen: true,
            ),
          ),
        );
        if (selected != true) {
          if (!mounted) return;
          setState(() {
            _switchingProviderId = null;
            _feedback = context.tr(
              '语音服务已连接，请选择一个朗读音色以完成设置。',
              'The provider is connected. Choose a reading voice to finish setup.',
            );
          });
          return;
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _switchingProviderId = null;
        _feedback = context.tr(
          '无法切换服务，请打开详情检查凭据或网络连接。',
          'Could not switch providers. Open details to check credentials or your connection.',
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
  final bool adding;

  const TtsProviderDetailsScreen({
    super.key,
    required this.providerId,
    this.adding = false,
  });

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
  bool _deleting = false;
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
    return CollapsingPageScaffold(
      title: widget.adding
          ? context.tr('添加语音服务', 'Add Voice Provider')
          : provider.displayName,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          helperText: widget.adding
                              ? context.tr('必填', 'Required')
                              : context.tr(
                                  '留空可保留已保存的凭据',
                                  'Leave empty to keep the saved credential',
                                ),
                        ),
                      ),
                      SizedBox(height: design.spaceLg),
                      _buildApiKeyGuide(provider),
                    ],
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
            ],
          ),
          SizedBox(height: design.spaceXl),
          if (provider is MinimaxTtsProvider ||
              provider is FishAudioApiTtsProvider)
            FilledButton.icon(
              key: const ValueKey('save-tts-provider'),
              onPressed: _saving
                  ? null
                  : widget.adding
                  ? () => _saveAndConnect(provider)
                  : () => _saveKey(provider),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                widget.adding
                    ? context.tr('保存并连接', 'Save and connect')
                    : context.tr('保存凭据', 'Save credentials'),
              ),
            ),
          if (!widget.adding) ...[
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
            SizedBox(height: design.spaceXl),
            TextButton.icon(
              key: const ValueKey('delete-tts-provider'),
              onPressed: _deleting ? null : () => _deleteProvider(provider),
              icon: _deleting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: Text(context.tr('删除语音服务', 'Delete provider')),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveAndConnect(Object provider) async {
    final key = _apiKeyController.text.trim();
    final connectionError = context.tr(
      '连接失败，请检查 API Key 和网络。',
      'Connection failed. Check the API key and your network.',
    );
    if (key.isEmpty) {
      setState(() {
        _feedback = context.tr('请输入 API Key。', 'Enter an API key.');
        _feedbackIsError = true;
      });
      return;
    }
    setState(() {
      _saving = true;
      _feedback = null;
      _feedbackIsError = false;
    });
    try {
      await _writeApiKey(provider, key);
      final valid = switch (provider) {
        MinimaxTtsProvider value => await value.validate(),
        FishAudioApiTtsProvider value => await value.validate(),
        _ => false,
      };
      if (!valid) {
        throw StateError(connectionError);
      }
      await ref
          .read(ttsSettingsControllerProvider.notifier)
          .selectProvider(widget.providerId);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _feedback = context.tr(
          '连接成功，正在同步云端音色。请选择一个朗读音色。',
          'Connected. Cloud voices are syncing; choose a reading voice.',
        );
        _feedbackIsError = false;
      });
      final selected = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              const VoiceLibraryScreen(guidedSelection: true, syncOnOpen: true),
        ),
      );
      ref.invalidate(ttsProviderConfigurationStatusProvider);
      ref.invalidate(ttsSettingsControllerProvider);
      if (!mounted) return;
      if (selected == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _feedback = context.tr(
            '语音服务已连接，请选择一个朗读音色以完成设置。',
            'The provider is connected. Choose a reading voice to finish setup.',
          );
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _feedback = '$error';
        _feedbackIsError = true;
      });
    }
  }

  Widget _buildApiKeyGuide(Object provider) {
    final isFishAudio = provider is FishAudioApiTtsProvider;
    final uri = isFishAudio
        ? Uri.parse('https://fish.audio/app/api-keys/')
        : Uri.parse(
            'https://platform.minimaxi.com/console/access?tab=api-keys',
          );
    final steps = isFishAudio
        ? context.tr(
            '1. 登录或注册 Fish Audio\n'
                '2. 点击 Create API Key 创建密钥\n'
                '3. 复制密钥并粘贴到上方',
            '1. Sign in or create a Fish Audio account\n'
                '2. Select Create API Key\n'
                '3. Copy the key and paste it above',
          )
        : context.tr(
            '1. 登录 MiniMax 开放平台\n'
                '2. 进入账户管理 > 接口密钥\n'
                '3. 创建新的 API Key，复制并粘贴到上方',
            '1. Sign in to the MiniMax Open Platform\n'
                '2. Open Account management > API keys\n'
                '3. Create a new API key, then copy and paste it above',
          );
    final buttonLabel = isFishAudio
        ? context.tr('打开 Fish Audio API Keys', 'Open Fish Audio API Keys')
        : context.tr('打开 MiniMax 接口密钥', 'Open MiniMax API Keys');
    final colors = Theme.of(context).colorScheme;
    final design = context.appDesign;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(design.radiusSmall),
      ),
      child: Padding(
        padding: EdgeInsets.all(design.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.key_outlined, size: 20, color: colors.primary),
                SizedBox(width: design.spaceSm),
                Expanded(
                  child: Text(
                    context.tr('在哪里获取 API Key？', 'Where do I get an API key?'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            SizedBox(height: design.spaceSm),
            Text(steps, style: Theme.of(context).textTheme.bodySmall),
            SizedBox(height: design.spaceSm),
            TextButton.icon(
              key: ValueKey('get-tts-api-key-${widget.providerId}'),
              onPressed: () => _openApiKeyPage(uri),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(buttonLabel),
            ),
            Text(
              context.tr(
                '密钥只保存在此设备上。云服务可能产生费用，请查看服务商定价。',
                'The key stays on this device. Cloud usage may incur charges; check the provider pricing.',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openApiKeyPage(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {
      // The fallback below also handles platform launch failures.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            '无法打开网页，请在浏览器中访问：$uri',
            'Could not open the page. Visit this address in a browser: $uri',
          ),
        ),
      ),
    );
  }

  Future<void> _saveKey(Object provider) async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;
    setState(() => _saving = true);
    await _writeApiKey(provider, key);
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

  Future<void> _writeApiKey(Object provider, String key) async {
    if (provider is MinimaxTtsProvider) await provider.setApiKey(key);
    if (provider is FishAudioApiTtsProvider) await provider.setApiKey(key);
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
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activating = false;
        _feedback = context.tr(
          '无法使用此服务，请检查凭据或网络连接。',
          'Could not use this provider. Check credentials or your connection.',
        );
        _feedbackIsError = true;
      });
    }
  }

  Future<void> _deleteProvider(Object provider) async {
    final providerName = switch (provider) {
      FishAudioApiTtsProvider value => value.displayName,
      MinimaxTtsProvider value => value.displayName,
      _ => widget.providerId,
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('删除语音服务？', 'Delete voice provider?')),
        content: Text(
          context.tr(
            '将从此设备删除 $providerName 的 API Key、已同步音色和音色选择。'
                '不会删除云端账号或云端音色。',
            'This removes the $providerName API key, synced voices, and voice selection from this device. '
                'It does not delete your cloud account or cloud voices.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-tts-provider'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(context.tr('删除', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deleting = true;
      _feedback = null;
      _feedbackIsError = false;
    });
    try {
      await ref
          .read(ttsSettingsControllerProvider.notifier)
          .removeProvider(widget.providerId);
      ref.invalidate(ttsProviderConfigurationStatusProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _feedback = context.tr(
          '删除失败：$error',
          'Could not delete the provider: $error',
        );
        _feedbackIsError = true;
      });
    }
  }
}
