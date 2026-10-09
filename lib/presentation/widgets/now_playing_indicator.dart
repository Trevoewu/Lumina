import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_system/app_icon.dart';

const _nowPlayingSymbolViewType = 'lumina/now_playing_symbol';

/// The waveform that marks what is playing. On iOS it is the SF Symbol
/// running the system's variable-colour effect while [animating]; elsewhere
/// it is the app's still waveform icon.
class NowPlayingIndicator extends StatelessWidget {
  final bool animating;
  final Color color;
  final double size;

  const NowPlayingIndicator({
    super.key,
    required this.animating,
    required this.color,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS || kIsWeb) {
      return AppIcon(AppIcons.audioWave01, size: size, color: color);
    }
    return SizedBox.square(
      dimension: size + 8,
      child: UiKitView(
        // The native view reads its settings once, so a change of state
        // builds a new one.
        key: ValueKey('now-playing-$animating-${color.toARGB32()}'),
        viewType: _nowPlayingSymbolViewType,
        creationParams: <String, dynamic>{
          'animating': animating,
          'color': color.toARGB32(),
          'size': size,
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
