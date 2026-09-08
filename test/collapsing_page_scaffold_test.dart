import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/app_colors.dart';
import 'package:lumina/core/theme.dart';
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

  testWidgets('page header stays neutral and collapses its single title', (
    tester,
  ) async {
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
    // Opaque background keeps scrolling body content from ghosting through
    // the pinned header while matching the scaffold color at rest.
    expect(header.color, AppColors.darkColorScheme.surface);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('collapsing-page-title')))
          .style
          ?.fontSize,
      34,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('collapsing-page-title')))
          .style
          ?.fontWeight,
      FontWeight.w700,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('collapsing-page-title'))).dx,
      closeTo(16, 0.1),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();

    final collapsedTitle = tester.widget<Text>(
      find.byKey(const ValueKey('collapsing-page-title')),
    );
    expect(collapsedTitle.style?.fontSize, closeTo(18, 0.1));
    expect(collapsedTitle.style?.fontWeight, FontWeight.w700);
    expect(find.text('Library'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
