import 'package:flutter/material.dart';

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

/// Shows the card action menu as a dimmed, rounded, half-height sheet.
Future<void> showHalfScreenActionSheet(
  BuildContext context, {
  required String title,
  required List<HalfScreenActionSheetItem> actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.52),
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
    final mediaQuery = MediaQuery.of(context);
    // Keep the sheet compact for short menus, while allowing long menus to
    // scroll instead of extending beneath the status bar.
    const handleAreaHeight = 28.0;
    const headerHeight = 60.0;
    const actionHeight = 61.0;
    final verticalPadding = design.spaceXs + design.spaceLg;
    final contentHeight =
        handleAreaHeight +
        headerHeight +
        verticalPadding +
        actions.length * actionHeight +
        (actions.length - 1).clamp(0, double.maxFinite) * design.spaceXs +
        mediaQuery.padding.bottom;
    final maxHeight = mediaQuery.size.height * 0.78;
    final sheetHeight = contentHeight.clamp(0.0, maxHeight).toDouble();

    return SizedBox(
      height: sheetHeight,
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
              // The handle belongs inside the sheet, below its rounded edge.
              SizedBox(
                height: handleAreaHeight,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appTextSecondary.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
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
