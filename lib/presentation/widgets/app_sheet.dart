import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// Shared presentation only: Flutter owns the sheet transition and gestures.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool enableDrag = true,
}) {
  final themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: true).context,
  );
  return showCupertinoSheet<T>(
    context: context,
    enableDrag: enableDrag,
    scrollableBuilder: (sheetContext, scrollController) => themes.wrap(
      Builder(
        builder: (context) => Scaffold(
          backgroundColor: context.appSurface,
          // Scaffold handles the keyboard inset once for every sheet.
          body: SafeArea(
            top: false,
            child: PrimaryScrollController(
              controller: scrollController,
              automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox.expand(child: Builder(builder: builder)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
