import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import 'app_back_button.dart';

/// Read long card content with the native sheet's scrolling and dismissal.
Future<void> showAppContentSheet({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) => showAppSheet<void>(
  context: context,
  backButtonKey: const ValueKey('app-content-sheet-close'),
  builder: (context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SizedBox(width: double.infinity, child: builder(context)),
        ),
      ),
    ],
  ),
);

/// Shared presentation only: Flutter owns the sheet transition and gestures.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool enableDrag = true,
  Key? backButtonKey,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AppBackButton(key: backButtonKey),
                      ),
                    ),
                    Expanded(child: Builder(builder: builder)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
