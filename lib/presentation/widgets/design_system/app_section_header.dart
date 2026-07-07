import 'package:flutter/material.dart';

import '../../../core/app_design_tokens.dart';

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding,
  }) : assert(actionLabel == null || onAction != null);

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    return Padding(
      padding:
          padding ??
          EdgeInsets.only(top: design.spaceXl, bottom: design.spaceSm),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
