import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';

/// Plain playback controls, with no glass surface or native glass button.
class AppControlIconButton extends StatelessWidget {
  const AppControlIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.selected,
  });

  final AppIconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;
  final bool? selected;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: IconButton(
      icon: AppIcon(icon),
      iconSize: 22,
      style: const ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      color: color,
      tooltip: tooltip,
      onPressed: onPressed,
    ),
  );
}

class AppControlTextButton extends StatelessWidget {
  const AppControlTextButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: SizedBox.square(
      dimension: 44,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          foregroundColor: color,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    ),
  );
}
