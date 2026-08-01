import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const _airPlayRoutePickerViewType = 'lumina/airplay_route_picker';

/// Whether this platform can present a system audio-route picker.
///
/// Only iOS is wired up. AirPlay has no Android equivalent — the closest is the
/// Cast `MediaRouteButton`, which is a different service with its own SDK — and
/// macOS would need a separate AppKit platform view.
bool get airPlayRoutePickerSupported =>
    defaultTargetPlatform == TargetPlatform.iOS;

/// The system AirPlay button, hosted as a platform view.
///
/// `AVRoutePickerView` renders its own glyph and reflects the active route on
/// its own — it turns [activeColor] while audio is playing somewhere else — so
/// there is deliberately no Flutter-side icon or pressed state here. Callers
/// should check [airPlayRoutePickerSupported] before building one.
class AirPlayRoutePickerButton extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final Color activeColor;
  final String semanticLabel;

  const AirPlayRoutePickerButton({
    super.key,
    required this.width,
    required this.height,
    required this.color,
    required this.activeColor,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: width,
        height: height,
        child: UiKitView(
          viewType: _airPlayRoutePickerViewType,
          creationParams: <String, dynamic>{
            'tintColor': color.toARGB32(),
            'activeTintColor': activeColor.toARGB32(),
          },
          creationParamsCodec: const StandardMessageCodec(),
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        ),
      ),
    );
  }
}
