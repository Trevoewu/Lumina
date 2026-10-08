import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/app_colors.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/presentation/widgets/app_back_button.dart';
import 'package:lumina/presentation/widgets/collapsing_page_scaffold.dart';

void main() {
  testWidgets('stationary header follows light and dark theme changes', (
    tester,
  ) async {
    final mode = ValueNotifier(ThemeMode.light);
    addTearDown(mode.dispose);
    final page = CollapsingPageScaffold(
      title: 'Settings',
      showBackButton: true,
      body: ListView(children: const [SizedBox(height: 2000)]),
    );
    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: mode,
        builder: (_, value, child) => MaterialApp(
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: value,
          home: child,
        ),
        child: page,
      ),
    );

    final titleFinder = find.byKey(const ValueKey('collapsing-page-title'));
    final initialPosition = tester.getTopLeft(titleFinder);
    for (final value in [ThemeMode.dark, ThemeMode.light, ThemeMode.dark]) {
      mode.value = value;
      await tester.pumpAndSettle();
      final scheme = value == ThemeMode.dark
          ? AppColors.darkColorScheme
          : AppColors.lightColorScheme;
      expect(
        tester
            .widget<Material>(
              find.byKey(const ValueKey('collapsing-page-header')),
            )
            .color,
        scheme.surface,
      );
      expect(tester.widget<Text>(titleFinder).style?.color, scheme.onSurface);
      expect(tester.getTopLeft(titleFinder), initialPosition);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'page header uses flat title that scrolls off screen with content',
    (tester) async {
      tester.view.physicalSize = const Size(430, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(accentColor: Colors.redAccent),
          home: CollapsingPageScaffold(
            title: 'Library',
            body: ListView.builder(
              itemCount: 40,
              itemBuilder: (_, index) =>
                  SizedBox(height: 64, child: Text('Item $index')),
            ),
          ),
        ),
      );

      final header = tester.widget<Material>(
        find.byKey(const ValueKey('collapsing-page-header')),
      );
      expect(header.color, AppColors.darkColorScheme.surface);

      final titleFinder = find.byKey(const ValueKey('collapsing-page-title'));
      final initialPos = tester.getTopLeft(titleFinder);
      expect(tester.widget<Text>(titleFinder).style?.fontSize, 32);
      expect(
        tester.widget<Text>(titleFinder).style?.fontWeight,
        FontWeight.w800,
      );
      expect(initialPos.dx, closeTo(22, 0.1));

      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();

      // The header has flat typography and scrolls away with page content rather than
      // centering or pinning at a shrunk size.
      expect(find.byKey(const ValueKey('collapsing-page-title')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back button stays on screen while the page scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: CollapsingPageScaffold(
          title: 'Settings',
          showBackButton: true,
          body: ListView.builder(
            itemCount: 40,
            itemBuilder: (_, index) =>
                SizedBox(height: 64, child: Text('Item $index')),
          ),
        ),
      ),
    );

    final toolbar = find.byKey(const ValueKey('collapsing-page-toolbar'));
    final compactTitle = find.byKey(
      const ValueKey('collapsing-page-compact-title'),
    );
    final toolbarTop = tester.getTopLeft(toolbar);
    expect(compactTitle, findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('collapsing-page-title')), findsNothing);
    expect(tester.getTopLeft(toolbar), toolbarTop);
    expect(
      find.descendant(of: toolbar, matching: find.byType(AppBackButton)),
      findsOneWidget,
    );
    expect(compactTitle, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
