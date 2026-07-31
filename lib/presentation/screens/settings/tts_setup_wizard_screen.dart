import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/service_settings_controllers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../tts/models/tts_model.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/providers/fish_audio_api_tts_provider.dart';
import '../../../tts/providers/minimax_tts_provider.dart';
import '../../../tts/tts_provider.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/app_section_header.dart';
import '../../widgets/design_system/provider_brand_icon.dart';
import '../../widgets/design_system/settings_components.dart';

class TtsSetupWizardScreen extends ConsumerStatefulWidget {
  const TtsSetupWizardScreen({super.key});

  @override
  ConsumerState<TtsSetupWizardScreen> createState() =>
      _TtsSetupWizardScreenState();
}

class _TtsSetupWizardScreenState extends ConsumerState<TtsSetupWizardScreen> {
  final _apiKey = TextEditingController();
  int _step = 0;
  bool _forward = true;
  bool _initializing = true;
  bool _busy = false;
  String? _providerId;
  String? _modelId;
  String? _voiceId;
  String? _error;
  List<TtsModel> _models = const [];
  List<drift_db.Voice> _voices = const [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final settings = await ref.read(ttsSettingsControllerProvider.future);
      final configured = await ref.read(
        ttsProviderConfigurationStatusProvider.future,
      );
      final providerId = settings.providerId;
      var initialStep = 0;
      if (providerId != null && configured[providerId] == true) {
        _providerId = providerId;
        _modelId = settings.modelId;
        _voiceId = settings.voiceId;
        if (settings.modelId == null) {
          initialStep = 2;
          await _loadModels(providerId);
        } else {
          initialStep = 3;
          await _loadVoices(providerId);
        }
      }
      if (!mounted) return;
      setState(() {
        _step = initialStep;
        _initializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return CollapsingPageScaffold(
      title: context.tr('语音设置', 'Voice Setup'),
      showBackButton: true,
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    design.spaceSm,
                    inset,
                    design.spaceMd,
                  ),
                  child: SetupProgressHeader(
                    title: context.tr('语音设置进度', 'Voice setup progress'),
                    steps: [
                      'Provider',
                      context.tr('密钥', 'Key'),
                      context.tr('模型', 'Model'),
                      'Voice',
                    ],
                    currentStep: _step,
                  ),
                ),
                Expanded(
                  child: SetupStepTransition(
                    step: _step,
                    forward: _forward,
                    child: _buildStep(inset),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      design.spaceSm,
                      inset,
                      design.spaceMd,
                    ),
                    child: SetupNavigationBar(
                      previousLabel: context.tr('上一步', 'Previous'),
                      nextLabel: _step == 3
                          ? context.tr('完成', 'Finish')
                          : context.tr('下一步', 'Next'),
                      busy: _busy,
                      onPrevious: _previous,
                      onNext: _canContinue ? _next : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  bool get _canContinue => switch (_step) {
    0 => _providerId != null,
    1 => _providerId != null,
    2 => _modelId != null,
    3 => _voiceId != null,
    _ => false,
  };

  Widget _buildStep(double inset) {
    final design = context.appDesign;
    return ListView(
      key: ValueKey('tts-wizard-step-$_step'),
      padding: EdgeInsets.fromLTRB(inset, 0, inset, design.spaceXl),
      children: [
        if (_error != null) ...[
          SettingsFeedbackBanner(message: _error!, error: true),
          SizedBox(height: design.spaceMd),
        ],
        switch (_step) {
          0 => _providerStep(),
          1 => _keyStep(),
          2 => _modelStep(),
          _ => _voiceStep(),
        },
      ],
    );
  }

  Widget _providerStep() {
    final choices = [
      (
        FishAudioApiTtsProvider.idValue,
        'Fish Audio',
        context.tr(
          '自然语音、声音克隆与流式合成',
          'Natural voices, voice cloning, and streaming synthesis',
        ),
      ),
      (
        MinimaxTtsProvider.idValue,
        'MiniMax',
        context.tr(
          '高质量语音、声音克隆与声音设计',
          'High-quality speech, cloning, and voice design',
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: context.tr('选择语音服务', 'Choose a voice provider'),
        ),
        SettingsGroup(
          children: [
            for (final choice in choices)
              ListTile(
                key: ValueKey('wizard-tts-provider-${choice.$1}'),
                leading: ProviderBrandIcon(
                  brand: providerBrandForTtsId(choice.$1)!,
                  selected: _providerId == choice.$1,
                ),
                title: Text(choice.$2),
                subtitle: Text(choice.$3),
                trailing: Icon(
                  _providerId == choice.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                selected: _providerId == choice.$1,
                onTap: () => setState(() {
                  _providerId = choice.$1;
                  _modelId = null;
                  _voiceId = null;
                  _error = null;
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _keyStep() {
    final provider = ref.read(providerRegistryProvider).get(_providerId!);
    final isFish = provider is FishAudioApiTtsProvider;
    final uri = Uri.parse(
      isFish
          ? 'https://fish.audio/app/api-keys/'
          : 'https://platform.minimaxi.com/console/access?tab=api-keys',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: context.tr(
            '连接 ${provider?.displayName ?? 'Provider'}',
            'Connect ${provider?.displayName ?? 'Provider'}',
          ),
        ),
        SettingsFeedbackBanner(
          message: context.tr(
            '先获取 API Key，粘贴并验证连接。成功后将在当前页面继续选择模型。',
            'Get an API key, paste it below, and verify the connection. Model selection continues on this page.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('wizard-tts-api-key'),
          controller: _apiKey,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'API Key',
            helperText: context.tr(
              '已保存过密钥时可留空',
              'Leave empty to use an already saved key',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('在哪里获取 API Key？', 'Where do I get an API key?'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    '1. 登录 ${isFish ? 'Fish Audio' : 'MiniMax'} 控制台\n'
                        '2. 打开 API Keys 页面并创建密钥\n'
                        '3. 复制密钥并粘贴到上方',
                    '1. Sign in to the ${isFish ? 'Fish Audio' : 'MiniMax'} console\n'
                        '2. Open API Keys and create a key\n'
                        '3. Copy the key and paste it above',
                  ),
                ),
                TextButton.icon(
                  key: ValueKey('get-tts-api-key-$_providerId'),
                  onPressed: () => _openUrl(uri),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(context.tr('打开 API Keys', 'Open API Keys')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _modelStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSectionHeader(title: context.tr('选择语音模型', 'Choose a voice model')),
      if (_models.isEmpty)
        SettingsEmptyState(
          icon: Icons.model_training_outlined,
          message: context.tr('没有找到可用模型', 'No models are available'),
          actionLabel: context.tr('重新同步', 'Sync again'),
          onAction: () => _reloadModels(),
        )
      else
        SettingsGroup(
          children: [
            for (final model in _models)
              ListTile(
                key: ValueKey('wizard-tts-model-${model.id}'),
                title: Text(model.name),
                subtitle: Text(model.description),
                trailing: _modelId == model.id
                    ? const Icon(Icons.radio_button_checked)
                    : const Icon(Icons.radio_button_off),
                selected: _modelId == model.id,
                onTap: () => setState(() {
                  _modelId = model.id;
                  _error = null;
                }),
              ),
          ],
        ),
    ],
  );

  Widget _voiceStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSectionHeader(title: context.tr('选择朗读音色', 'Choose a reading voice')),
      if (_voices.isEmpty)
        SettingsEmptyState(
          icon: Icons.record_voice_over_outlined,
          message: context.tr('没有找到可用音色', 'No voices are available'),
          actionLabel: context.tr('重新同步', 'Sync again'),
          onAction: () => _reloadVoices(),
        )
      else
        SettingsGroup(
          children: [
            for (final voice in _voices)
              ListTile(
                key: ValueKey('wizard-tts-voice-${voice.id}'),
                leading: const Icon(Icons.record_voice_over_outlined),
                title: Text(voice.name),
                subtitle: voice.presetDescription == null
                    ? null
                    : Text(voice.presetDescription!),
                trailing: _voiceId == voice.id
                    ? const Icon(Icons.radio_button_checked)
                    : const Icon(Icons.radio_button_off),
                selected: _voiceId == voice.id,
                onTap: () => setState(() {
                  _voiceId = voice.id;
                  _error = null;
                }),
              ),
          ],
        ),
    ],
  );

  void _previous() {
    if (_busy) return;
    if (_step == 0) {
      Navigator.of(context).pop(false);
      return;
    }
    _goTo(_step - 1);
  }

  Future<void> _next() async {
    switch (_step) {
      case 0:
        _goTo(1);
      case 1:
        await _connectProvider();
      case 2:
        await _saveModel();
      case 3:
        await _finish();
    }
  }

  void _goTo(int step) {
    setState(() {
      _forward = step > _step;
      _step = step;
      _error = null;
    });
  }

  Future<void> _connectProvider() async {
    final providerId = _providerId!;
    final provider = ref.read(providerRegistryProvider).get(providerId);
    if (provider == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final missingKeyMessage = context.tr('请输入 API Key。', 'Enter an API key.');
    final connectionErrorMessage = context.tr(
      '连接失败，请检查 API Key 和网络。',
      'Connection failed. Check the API key and your network.',
    );
    try {
      final key = _apiKey.text.trim();
      switch (provider) {
        case FishAudioApiTtsProvider value:
          if (key.isNotEmpty) await value.setApiKey(key);
          if ((await value.apiKey)?.trim().isEmpty != false) {
            throw StateError(missingKeyMessage);
          }
        case MinimaxTtsProvider value:
          if (key.isNotEmpty) await value.setApiKey(key);
          if ((await value.apiKey)?.trim().isEmpty != false) {
            throw StateError(missingKeyMessage);
          }
        default:
          throw StateError('Unsupported provider');
      }
      if (!await provider.validate()) {
        throw StateError(connectionErrorMessage);
      }
      await ref
          .read(ttsSettingsControllerProvider.notifier)
          .selectProvider(providerId);
      await _loadModels(providerId, refresh: true);
      if (mounted) _goTo(2);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveModel() async {
    final providerId = _providerId!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(providerSelectionRepositoryProvider)
          .setSelectedTtsModel(providerId, _modelId);
      await _loadVoices(providerId);
      if (mounted) _goTo(3);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(providerSelectionRepositoryProvider)
          .setSelectedVoice(_providerId!, _voiceId);
      ref.invalidate(ttsProviderConfigurationStatusProvider);
      ref.invalidate(ttsSettingsControllerProvider);
      await ref.read(ttsSettingsControllerProvider.future);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadModels(String providerId, {bool refresh = false}) async {
    final provider = ref.read(providerRegistryProvider).get(providerId);
    final models = switch (provider) {
      final TtsModelCatalog catalog => await catalog.listModels(
        refresh: refresh,
      ),
      _ => const <TtsModel>[],
    };
    _models = models;
    if (_modelId != null && !models.any((item) => item.id == _modelId)) {
      _modelId = null;
    }
  }

  Future<void> _loadVoices(String providerId) async {
    final provider = ref.read(providerRegistryProvider).get(providerId);
    if (provider == null) return;
    final database = ref.read(appDatabaseProvider);
    try {
      final remoteVoices = await provider.listPresetVoices();
      for (final voice in remoteVoices) {
        await database.upsertVoice(
          drift_db.Voice(
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
          ),
        );
      }
    } catch (_) {
      final stored = await database.getVoicesByProvider(providerId);
      if (stored.isEmpty) rethrow;
    }
    final voices = await database.getVoicesByProvider(providerId);
    _voices = voices;
    if (_voiceId != null && !voices.any((item) => item.id == _voiceId)) {
      _voiceId = null;
    }
  }

  Future<void> _reloadModels() async {
    setState(() => _busy = true);
    try {
      await _loadModels(_providerId!, refresh: true);
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reloadVoices() async {
    setState(() => _busy = true);
    try {
      await _loadVoices(_providerId!);
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openUrl(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(uri.toString())));
  }
}
