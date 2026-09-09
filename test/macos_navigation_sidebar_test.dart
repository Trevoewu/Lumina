import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/widgets/app_scaffold.dart';
import 'package:lumina/presentation/widgets/design_system/macos_window_toolbar.dart';

void main() {
  group('MacosWindowToolbar', () {
    testWidgets('renders toolbar buttons and handles toggle, back, and forward', (
      tester,
    ) async {
      bool toggleClicked = false;
      bool backClicked = false;
      bool forwardClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MacosWindowToolbar(
              isSidebarVisible: true,
              onToggleSidebar: () => toggleClicked = true,
              canGoBack: true,
              onBack: () => backClicked = true,
              canGoForward: true,
              onForward: () => forwardClicked = true,
            ),
          ),
        ),
      );

      final toggleFinder = find.byKey(
        const ValueKey('macos-sidebar-toggle-button'),
      );
      final backFinder = find.byKey(const ValueKey('macos-back-button'));
      final forwardFinder = find.byKey(const ValueKey('macos-forward-button'));

      expect(toggleFinder, findsOneWidget);
      expect(backFinder, findsOneWidget);
      expect(forwardFinder, findsOneWidget);

      await tester.tap(toggleFinder);
      expect(toggleClicked, isTrue);

      await tester.tap(backFinder);
      expect(backClicked, isTrue);

      await tester.tap(forwardFinder);
      expect(forwardClicked, isTrue);
    });

    testWidgets('disabled back and forward buttons ignore taps', (
      tester,
    ) async {
      bool backClicked = false;
      bool forwardClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MacosWindowToolbar(
              isSidebarVisible: false,
              onToggleSidebar: () {},
              canGoBack: false,
              onBack: () => backClicked = true,
              canGoForward: false,
              onForward: () => forwardClicked = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('macos-back-button')));
      expect(backClicked, isFalse);

      await tester.tap(find.byKey(const ValueKey('macos-forward-button')));
      expect(forwardClicked, isFalse);
    });
  });

  group('AppScaffold macOS desktop layout', () {
    late AppDatabase database;
    late ProviderContainer container;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      database.close();
    });

    Widget buildTestApp() {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            platform: TargetPlatform.macOS,
            colorScheme: const ColorScheme.light(
              surface: Colors.white,
              onSurface: Colors.black,
              primary: Colors.blue,
            ),
          ),
          home: const AppScaffold(),
        ),
      );
    }

    testWidgets('renders top toolbar and resizable navigation rail on macOS', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // MacosWindowToolbar is present
      expect(find.byType(MacosWindowToolbar), findsOneWidget);

      // NavigationRail is initially extended (width >= 160)
      final railFinder = find.byType(NavigationRail);
      expect(railFinder, findsOneWidget);
      NavigationRail rail = tester.widget<NavigationRail>(railFinder);
      expect(rail.extended, isTrue);

      // Click toggle sidebar button to hide sidebar
      final toggleFinder = find.byKey(
        const ValueKey('macos-sidebar-toggle-button'),
      );
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Sidebar AnimatedContainer has width 0
      final animatedContainerFinder = find.byWidgetPredicate(
        (w) => w is AnimatedContainer && w.constraints?.maxWidth == 0.0,
      );
      expect(animatedContainerFinder, findsOneWidget);

      // Click toggle button again to restore sidebar
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      rail = tester.widget<NavigationRail>(railFinder);
      expect(rail.extended, isTrue);
    });

    testWidgets('tab switching and back/forward navigation in top toolbar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final backButton = find.byKey(const ValueKey('macos-back-button'));
      final forwardButton = find.byKey(const ValueKey('macos-forward-button'));

      // Initially at root of tab 0 (Home), back and forward are disabled
      MacosWindowToolbar toolbar = tester.widget<MacosWindowToolbar>(
        find.byType(MacosWindowToolbar),
      );
      expect(toolbar.canGoBack, isFalse);
      expect(toolbar.canGoForward, isFalse);

      // Switch to tab 1 ("发现" / Discover)
      await tester.tap(find.text('发现'));
      await tester.pumpAndSettle();

      toolbar = tester.widget<MacosWindowToolbar>(
        find.byType(MacosWindowToolbar),
      );
      expect(toolbar.canGoBack, isTrue);
      expect(toolbar.canGoForward, isFalse);

      // Tap back button
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Returned to tab 0 ("主页")
      toolbar = tester.widget<MacosWindowToolbar>(
        find.byType(MacosWindowToolbar),
      );
      expect(toolbar.canGoForward, isTrue);

      // Tap forward button
      await tester.tap(forwardButton);
      await tester.pumpAndSettle();

      // Forwarded back to tab 1 ("发现")
      toolbar = tester.widget<MacosWindowToolbar>(
        find.byType(MacosWindowToolbar),
      );
      expect(toolbar.canGoBack, isTrue);
      expect(toolbar.canGoForward, isFalse);
    });

    testWidgets(
      'dragging splitter resizes sidebar and switches to compact mode',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Locate draggable splitter
        final splitterFinder = find.byWidgetPredicate(
          (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
        );
        expect(splitterFinder, findsOneWidget);

        // Drag splitter to the left by 80px (from 210 to 130px, which is < 160px)
        await tester.drag(splitterFinder, const Offset(-80, 0));
        await tester.pumpAndSettle();

        // NavigationRail should switch to compact mode (extended == false)
        final railFinder = find.byType(NavigationRail);
        expect(railFinder, findsOneWidget);
        final rail = tester.widget<NavigationRail>(railFinder);
        expect(rail.extended, isFalse);

        // Drag splitter to the right by 100px (back above 160px)
        await tester.drag(splitterFinder, const Offset(100, 0));
        await tester.pumpAndSettle();

        final expandedRail = tester.widget<NavigationRail>(railFinder);
        expect(expandedRail.extended, isTrue);

        // Drag splitter far to the left to trigger collapse (< 45px)
        await tester.drag(splitterFinder, const Offset(-220, 0));
        await tester.pumpAndSettle();

        // Sidebar collapsed
        final collapsedFinder = find.byWidgetPredicate(
          (w) => w is AnimatedContainer && w.constraints?.maxWidth == 0.0,
        );
        expect(collapsedFinder, findsOneWidget);
      },
    );

    testWidgets(
      'bottom Me profile card navigates to Me tab and updates rail selection',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Navigation rail contains exactly 3 top destinations
        final railFinder = find.byType(NavigationRail);
        expect(railFinder, findsOneWidget);
        NavigationRail rail = tester.widget<NavigationRail>(railFinder);
        expect(rail.destinations.length, equals(3));
        expect(rail.selectedIndex, equals(0));

        // Bottom profile card exists
        final profileCardFinder = find.byKey(
          const ValueKey('sidebar-me-profile-card'),
        );
        expect(profileCardFinder, findsOneWidget);
        expect(find.textContaining('Trevor'), findsOneWidget);
        expect(find.textContaining('Free'), findsOneWidget);

        // Tap bottom Me profile card
        await tester.tap(profileCardFinder);
        await tester.pumpAndSettle();

        // Rail selection is now null (none of the 3 rail destinations are active)
        rail = tester.widget<NavigationRail>(railFinder);
        expect(rail.selectedIndex, isNull);

        // Back button in toolbar is now enabled
        final backButton = find.byKey(const ValueKey('macos-back-button'));
        MacosWindowToolbar toolbar = tester.widget<MacosWindowToolbar>(
          find.byType(MacosWindowToolbar),
        );
        expect(toolbar.canGoBack, isTrue);

        // Tap back to return to Home (tab 0)
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        rail = tester.widget<NavigationRail>(railFinder);
        expect(rail.selectedIndex, equals(0));

        // Let stream subscriptions tear down before the test ends.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );

  });
}

