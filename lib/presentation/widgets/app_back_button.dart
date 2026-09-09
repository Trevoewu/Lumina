import 'package:flutter/material.dart';
import 'app_control_buttons.dart';
import 'design_system/app_icon.dart';

/// Shared plain back button with a 44-point touch target.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed, this.tooltip});

  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final label =
        tooltip ?? MaterialLocalizations.of(context).backButtonTooltip;
    return AppControlIconButton(
      icon: AppIcons.arrowLeft02,
      tooltip: label,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}
