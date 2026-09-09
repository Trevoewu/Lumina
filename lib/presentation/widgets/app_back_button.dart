import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/material.dart';

/// The shared native glass back button used by the player and sheets.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed, this.tooltip});

  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final label =
        tooltip ?? MaterialLocalizations.of(context).backButtonTooltip;
    return Semantics(
      label: label,
      button: true,
      child: Tooltip(
        message: label,
        child: CNButton.icon(
          icon: const CNSymbol('chevron.left', size: 22),
          config: const CNButtonConfig(
            style: CNButtonStyle.glass,
            width: 44,
            minHeight: 44,
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
