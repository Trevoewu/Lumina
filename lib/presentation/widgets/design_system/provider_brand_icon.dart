import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum ProviderBrand { fishAudio, minimax, deepSeek, openAi, zai }

ProviderBrand? providerBrandForTtsId(String providerId) => switch (providerId) {
  'fish_audio_api' => ProviderBrand.fishAudio,
  'minimax' => ProviderBrand.minimax,
  _ => null,
};

ProviderBrand? providerBrandForLlmKind(String kind) => switch (kind) {
  'openai' => ProviderBrand.openAi,
  'deepseek' => ProviderBrand.deepSeek,
  'zai' => ProviderBrand.zai,
  _ => null,
};

class ProviderBrandIcon extends StatelessWidget {
  final ProviderBrand brand;
  final bool selected;
  final double size;

  const ProviderBrandIcon({
    super.key,
    required this.brand,
    this.selected = false,
    this.size = 40,
  });

  String get _assetPath => switch (brand) {
    ProviderBrand.fishAudio => 'assets/provider_icons/fish_audio.svg',
    ProviderBrand.minimax => 'assets/provider_icons/minimax.svg',
    ProviderBrand.deepSeek => 'assets/provider_icons/deepseek.svg',
    ProviderBrand.openAi => 'assets/provider_icons/openai.svg',
    ProviderBrand.zai => 'assets/provider_icons/zai.svg',
  };

  String get _semanticLabel => switch (brand) {
    ProviderBrand.fishAudio => 'Fish Audio',
    ProviderBrand.minimax => 'MiniMax',
    ProviderBrand.deepSeek => 'DeepSeek',
    ProviderBrand.openAi => 'OpenAI',
    ProviderBrand.zai => 'Z.AI',
  };

  bool get _usesThemeColor => switch (brand) {
    ProviderBrand.fishAudio || ProviderBrand.openAi => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = SvgPicture.asset(
      _assetPath,
      key: ValueKey('provider-brand-${brand.name}'),
      width: size * 0.62,
      height: size * 0.62,
      fit: BoxFit.contain,
      semanticsLabel: _semanticLabel,
      colorFilter: _usesThemeColor
          ? ColorFilter.mode(scheme.onSurface, BlendMode.srcIn)
          : null,
    );
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(size * 0.28),
              ),
              child: Center(child: icon),
            ),
          ),
          if (selected)
            Positioned(
              right: -2,
              bottom: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Icon(Icons.check, size: 13, color: scheme.onPrimary),
              ),
            ),
        ],
      ),
    );
  }
}
