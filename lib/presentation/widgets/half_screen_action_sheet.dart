import 'package:flutter/material.dart';

import 'app_sheet.dart';
import '../../core/app_colors.dart';
import '../../core/app_design_tokens.dart';

/// An action that can be displayed in [showHalfScreenActionSheet].
class HalfScreenActionSheetItem {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;

  const HalfScreenActionSheetItem({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });
}

/// Shows the card action menu using the shared Cupertino sheet.
Future<void> showHalfScreenActionSheet(
  BuildContext context, {
  required String title,
  required List<HalfScreenActionSheetItem> actions,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (context) =>
        _HalfScreenActionSheet(title: title, actions: actions),
  );
}

class _HalfScreenActionSheet extends StatelessWidget {
  final String title;
  final List<HalfScreenActionSheetItem> actions;

  const _HalfScreenActionSheet({required this.title, required this.actions});

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    const headerHeight = 60.0;
    return SizedBox.expand(
      child: Material(
        color: context.appSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(design.radiusLarge * 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(
                height: headerHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: design.spaceXxl + 36,
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Positioned(
                      right: design.spaceSm,
                      child: IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    design.spaceLg,
                    0,
                    design.spaceLg,
                    design.spaceLg,
                  ),
                  itemCount: actions.length,
                  separatorBuilder: (_, _) => SizedBox(height: design.spaceXs),
                  itemBuilder: (context, index) {
                    final action = actions[index];
                    final enabled = action.onPressed != null;
                    final color = action.destructive
                        ? Theme.of(context).colorScheme.error
                        : context.appTextPrimary;

                    return Semantics(
                      button: enabled,
                      enabled: enabled,
                      label: action.label,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: enabled
                              ? () {
                                  Navigator.of(context).pop();
                                  action.onPressed!();
                                }
                              : null,
                          borderRadius: BorderRadius.circular(
                            design.radiusMedium,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: design.spaceSm,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  action.icon,
                                  color: enabled
                                      ? color
                                      : context.appTextSecondary.withValues(
                                          alpha: 0.5,
                                        ),
                                  size: 28,
                                ),
                                SizedBox(width: design.spaceLg),
                                Expanded(
                                  child: Text(
                                    action.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: enabled
                                          ? color
                                          : context.appTextSecondary.withValues(
                                              alpha: 0.5,
                                            ),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
