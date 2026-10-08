import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/player/player_screen.dart';
import 'package:lumina/presentation/screens/reader/book_reader_screen.dart';
import 'package:lumina/presentation/screens/settings/settings_screen.dart';
import 'package:lumina/presentation/widgets/app_back_button.dart';
import 'package:lumina/presentation/widgets/app_scaffold.dart';
import 'package:lumina/presentation/widgets/collapsing_page_scaffold.dart';
import 'package:lumina/presentation/widgets/design_system/macos_toolbar_providers.dart';
import 'package:lumina/presentation/widgets/design_system/macos_window_toolbar.dart';

void main() {
  group('MacosWindowToolbar', () {
    testWidgets(
      'renders toolbar buttons and handles toggle, back, and forward',
      (tester) async {
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
        final forwardFinder = find.byKey(
          const ValueKey('macos-forward-button'),
        );

        expect(toggleFinder, findsOneWidget);
        expect(backFinder, findsOneWidget);
        expect(forwardFinder, findsOneWidget);

        await tester.tap(toggleFinder);
        expect(toggleClicked, isTrue);

        await tester.tap(backFinder);
        expect(backClicked, isTrue);

        await tester.tap(forwardFinder);
        expect(forwardClicked, isTrue);
      },
    );

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
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
    });

    tearDown(() {
      container.dispose();
      database.close();
    });

    Widget buildTestApp({
      Widget? home,
      TargetPlatform platform = TargetPlatform.macOS,
    }) {
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
            platform: platform,
            colorScheme: const ColorScheme.light(
              surface: Colors.white,
              onSurface: Colors.black,
              primary: Colors.blue,
            ),
          ),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final isMac = Theme.of(context).platform == TargetPlatform.macOS;
            final mediaWithInsets = media.copyWith(
              padding: isMac
                  ? media.padding.copyWith(top: 36.0)
                  : media.padding,
              viewPadding: isMac
                  ? media.viewPadding.copyWith(top: 36.0)
                  : media.viewPadding,
            );
            return MediaQuery(
              data: mediaWithInsets,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: home ?? const AppScaffold(),
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

      // Persistent top control bar and sidebar toggle button are present
      final toggleFinder = find.byKey(
        const ValueKey('macos-sidebar-toggle-button'),
      );
      expect(toggleFinder, findsOneWidget);

      final selector = find.byKey(
        const ValueKey('home-section-selector-desktop'),
      );
      expect(selector, findsOneWidget);
      expect(tester.getTopLeft(selector).dy, 0);
      expect(tester.getSize(selector).height, macosTopControlsReservedHeight);

      // NavigationRail is initially extended (width >= 160)
      final railFinder = find.byType(NavigationRail);
      expect(railFinder, findsOneWidget);
      NavigationRail rail = tester.widget<NavigationRail>(railFinder);
      expect(rail.extended, isTrue);

      // Click toggle sidebar button to hide sidebar
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(selector).dy, 0);
      await tester.tap(find.text('书籍'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Sidebar AnimatedContainer has width 0
      final animatedContainerFinder = find.byWidgetPredicate(
        (w) => w is AnimatedContainer && w.constraints?.maxWidth == 0.0,
      );
      expect(animatedContainerFinder, findsOneWidget);

      // Click collapsed toggle button to restore sidebar
      final collapsedToggle = find.byKey(
        const ValueKey('macos-sidebar-toggle-button-collapsed'),
      );
      expect(collapsedToggle, findsOneWidget);
      await tester.tap(collapsedToggle);
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
      expect(tester.widget<MacosToolbarButton>(backButton).onPressed, isNull);
      expect(tester.widget<MacosToolbarButton>(forwardButton).onPressed, isNull);

      // Switch to tab 1 ("搜索" / Search)
      await tester.tap(find.text('搜索'));
      await tester.pumpAndSettle();

      expect(tester.widget<MacosToolbarButton>(backButton).onPressed, isNotNull);
      expect(tester.widget<MacosToolbarButton>(forwardButton).onPressed, isNull);

      // The page carries its own search field below the toolbar.
      expect(find.byKey(const ValueKey('search-field')), findsOneWidget);

      // Tap back button
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Returned to tab 0 ("主页")
      expect(tester.widget<MacosToolbarButton>(forwardButton).onPressed, isNotNull);

      // Tap forward button
      await tester.tap(forwardButton);
      await tester.pumpAndSettle();

      // Forwarded back to tab 1 ("搜索")
      expect(tester.widget<MacosToolbarButton>(backButton).onPressed, isNotNull);
      expect(tester.widget<MacosToolbarButton>(forwardButton).onPressed, isNull);
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
          (w) =>
              w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
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

        // The profile card opens Settings over the current tab.
        await tester.tap(profileCardFinder);
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);
        rail = tester.widget<NavigationRail>(railFinder);
        expect(rail.selectedIndex, equals(0));

        // Back button in toolbar is now enabled
        final backButton = find.byKey(const ValueKey('macos-back-button'));
        expect(tester.widget<MacosToolbarButton>(backButton).onPressed, isNotNull);

        // Back closes Settings and leaves Home in place.
        await tester.tap(backButton);
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsNothing);

        rail = tester.widget<NavigationRail>(railFinder);
        expect(rail.selectedIndex, equals(0));

        // Let stream subscriptions tear down before the test ends.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );

    testWidgets(
      'CollapsingPageScaffold suppresses redundant mobile AppBackButton on macOS and preserves on iOS',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // On macOS: mobile AppBackButton is suppressed
        await tester.pumpWidget(
          buildTestApp(
            platform: TargetPlatform.macOS,
            home: const CollapsingPageScaffold(
              title: '测试页面',
              showBackButton: true,
              body: SizedBox.expand(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AppBackButton), findsNothing);

        // On iOS: mobile AppBackButton is rendered
        await tester.pumpWidget(
          buildTestApp(
            platform: TargetPlatform.iOS,
            home: const CollapsingPageScaffold(
              title: '测试页面',
              showBackButton: true,
              body: SizedBox.expand(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AppBackButton), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'Opening SettingsScreen on macOS keeps desktop frame and MacosWindowToolbar active',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        final profileCard = find.byKey(
          const ValueKey('sidebar-me-profile-card'),
        );
        expect(profileCard, findsOneWidget);
        await tester.tap(profileCard);
        await tester.pumpAndSettle();

        // SettingsScreen is displayed
        expect(find.byType(SettingsScreen), findsOneWidget);
        // Mobile AppBackButton is not rendered in CollapsingPageScaffold
        expect(find.byType(AppBackButton), findsNothing);

        // The toolbar back button is enabled
        final toolbarBack = find.byKey(const ValueKey('macos-back-button'));
        expect(toolbarBack, findsOneWidget);
        expect(tester.widget<MacosToolbarButton>(toolbarBack).onPressed, isNotNull);
        await tester.tap(toolbarBack);
        await tester.pumpAndSettle();

        // Popped back to Home
        expect(find.byType(SettingsScreen), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'BookReaderScreen renders MacosWindowToolbar with 196pt channel and back button on macOS',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final testBook = Book(
          id: 'test-mac-book-1',
          title: 'Mac Reading Book',
          author: 'Author',
          language: 'english',
          format: 'epub',
          sourcePath: '/path/to/test.epub',
          chapterCount: 1,
          paragraphCount: 1,
          currentChapterId: 'ch-mac-1',
          currentParagraphIndex: 0,
          playbackOffsetMs: 0,
          importedAt: 1000,
          lastReadAt: 1000,
          isRead: false,
          kind: 'book',
          rightsStatus: 'public_domain',
        );

        const testChapter = Chapter(
          id: 'ch-mac-1',
          bookId: 'test-mac-book-1',
          chapterIndex: 0,
          title: 'Mac Chapter 1',
          textOffset: 0,
          isHidden: false,
        );

        await database.into(database.books).insert(testBook);
        await database.into(database.chapters).insert(testChapter);
        await database
            .into(database.paragraphs)
            .insert(
              const Paragraph(
                id: 'p-mac-1',
                chapterId: 'ch-mac-1',
                paragraphIndex: 0,
                content: 'Desktop navigation channel paragraph content.',
                bookId: 'test-mac-book-1',
              ),
            );

        final book = await database.getBook('test-mac-book-1');
        final chapters = await database.getChapters('test-mac-book-1');

        bool didPop = false;
        await tester.pumpWidget(
          buildTestApp(
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const ValueKey('open-reader-button'),
                      onPressed: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => BookReaderScreen(
                                  book: book!,
                                  initialChapter: chapters.first,
                                ),
                              ),
                            )
                            .then((_) => didPop = true);
                      },
                      child: const Text('Open Reader'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open the reader
        await tester.tap(find.byKey(const ValueKey('open-reader-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // Verify MacosWindowToolbar is rendered
        expect(find.byType(MacosWindowToolbar), findsOneWidget);
        // Verify redundant AppBackButton is NOT rendered
        expect(find.byType(AppBackButton), findsNothing);

        // Tap the toolbar back button
        final toolbarBack = find.byKey(const ValueKey('macos-back-button'));
        expect(toolbarBack, findsOneWidget);
        await tester.tap(toolbarBack);
        await tester.pumpAndSettle();

        expect(didPop, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'PlayerScreen renders MacosWindowToolbar channel and suppresses colliding close button on macOS',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final testBook = Book(
          id: 'test-mac-player-book',
          title: 'Mac Player Book',
          author: 'Author',
          language: 'english',
          format: 'epub',
          sourcePath: '/path/to/test.epub',
          chapterCount: 1,
          paragraphCount: 1,
          currentChapterId: 'ch-mac-player-1',
          currentParagraphIndex: 0,
          playbackOffsetMs: 0,
          importedAt: 1000,
          lastReadAt: 1000,
          isRead: false,
          kind: 'book',
          rightsStatus: 'public_domain',
        );

        const testChapter = Chapter(
          id: 'ch-mac-player-1',
          bookId: 'test-mac-player-book',
          chapterIndex: 0,
          title: 'Mac Chapter 1',
          textOffset: 0,
          isHidden: false,
        );

        await database.into(database.books).insert(testBook);
        await database.into(database.chapters).insert(testChapter);

        final book = await database.getBook('test-mac-player-book');
        final chapters = await database.getChapters('test-mac-player-book');

        bool didPop = false;
        await tester.pumpWidget(
          buildTestApp(
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const ValueKey('open-player-button'),
                      onPressed: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  book: book!,
                                  initialChapter: chapters.first,
                                  autoplayOnOpen: false,
                                ),
                              ),
                            )
                            .then((_) => didPop = true);
                      },
                      child: const Text('Open Player'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open the player
        await tester.tap(find.byKey(const ValueKey('open-player-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // Verify MacosWindowToolbar is rendered
        expect(find.byType(MacosWindowToolbar), findsOneWidget);
        // Verify colliding player-close-button and AppBackButton are NOT rendered
        expect(find.byKey(const ValueKey('player-close-button')), findsNothing);
        expect(find.byType(AppBackButton), findsNothing);

        // Tap the toolbar back button to pop player
        final toolbarBack = find.byKey(const ValueKey('macos-back-button'));
        expect(toolbarBack, findsOneWidget);
        await tester.tap(toolbarBack);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(didPop, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'PlayerScreen suppresses bottom MiniPlayer on desktop while active',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final testBook = Book(
          id: 'test-miniplayer-suppress-book',
          title: 'MiniPlayer Suppress Book',
          author: 'Author',
          language: 'english',
          format: 'epub',
          sourcePath: '/path/to/test.epub',
          chapterCount: 1,
          paragraphCount: 1,
          currentChapterId: 'ch-mini-1',
          currentParagraphIndex: 0,
          playbackOffsetMs: 0,
          importedAt: 1000,
          lastReadAt: 1000,
          isRead: false,
          kind: 'book',
          rightsStatus: 'public_domain',
        );
        final testChapter = Chapter(
          id: 'ch-mini-1',
          bookId: 'test-miniplayer-suppress-book',
          chapterIndex: 0,
          title: 'Chapter 1',
          textOffset: 0,
          isHidden: false,
        );
        await database.into(database.books).insert(testBook);
        await database.into(database.chapters).insert(testChapter);

        final book = await database.getBook('test-miniplayer-suppress-book');
        final chapters = await database.getChapters('test-miniplayer-suppress-book');

        bool didPop = false;
        await tester.pumpWidget(
          buildTestApp(
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const ValueKey('open-player-suppress-button'),
                      onPressed: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  book: book!,
                                  initialChapter: chapters.first,
                                  autoplayOnOpen: false,
                                ),
                              ),
                            )
                            .then((_) => didPop = true);
                      },
                      child: const Text('Open Player'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // miniPlayerSuppressedProvider should initially be false
        expect(container.read(miniPlayerSuppressedProvider), isFalse);

        // Open PlayerScreen
        await tester.tap(find.byKey(const ValueKey('open-player-suppress-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // When PlayerScreen is active, miniPlayerSuppressedProvider must be true
        expect(container.read(miniPlayerSuppressedProvider), isTrue);

        // Pop PlayerScreen via the toolbar back button
        final toolbarBack = find.byKey(const ValueKey('macos-back-button'));
        expect(toolbarBack, findsOneWidget);
        await tester.tap(toolbarBack);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        expect(didPop, isTrue);
        // After popping PlayerScreen, miniPlayerSuppressedProvider must return to false
        expect(container.read(miniPlayerSuppressedProvider), isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'AlbumScreen suppresses duplicate title and moves more button to top toolbar on macOS',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final testBook = Book(
          id: 'test-album-toolbar-book',
          title: 'Number the Stars',
          author: 'Lois Lowry',
          language: 'english',
          format: 'epub',
          sourcePath: '/path/to/test.epub',
          chapterCount: 1,
          paragraphCount: 1,
          currentParagraphIndex: 0,
          playbackOffsetMs: 0,
          importedAt: 1000,
          lastReadAt: 1000,
          isRead: false,
          kind: 'book',
          rightsStatus: 'public_domain',
        );
        final testChapter = Chapter(
          id: 'ch-album-1',
          bookId: 'test-album-toolbar-book',
          chapterIndex: 0,
          title: 'Chapter 1',
          textOffset: 0,
          isHidden: false,
        );
        await database.into(database.books).insert(testBook);
        await database.into(database.chapters).insert(testChapter);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Initially on root Home: + button is present, more button is absent
        expect(find.byKey(const ValueKey('home-add-action-desktop')), findsOneWidget);
        expect(find.byKey(const ValueKey('macos-book-detail-more-button')), findsNothing);

        // Open AlbumScreen by tapping the hero book in the library
        final heroFinder = find.byKey(const ValueKey('home-overview-hero'));
        expect(heroFinder, findsOneWidget);
        await tester.tap(heroFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // 1. Verify the duplicate large title in CollapsingPageScaffold is NOT rendered
        expect(find.byKey(const ValueKey('collapsing-page-title')), findsNothing);

        // 2. Verify the circular more menu button in the content area is NOT rendered
        expect(find.byKey(const ValueKey('book-detail-more-menu')), findsNothing);

        // 3. Verify the + button in top control bar is REPLACED by the more button
        expect(find.byKey(const ValueKey('home-add-action-desktop')), findsNothing);
        expect(find.byKey(const ValueKey('macos-book-detail-more-button')), findsOneWidget);

        // Pop AlbumScreen via toolbar back button
        final toolbarBack = find.byKey(const ValueKey('macos-back-button'));
        expect(toolbarBack, findsOneWidget);
        await tester.tap(toolbarBack);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // 4. After popping, top toolbar restores the + button and clears the more button
        expect(find.byKey(const ValueKey('home-add-action-desktop')), findsOneWidget);
        expect(find.byKey(const ValueKey('macos-book-detail-more-button')), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'BookReaderScreen hides All/Books/Podcast switcher, puts reader controls into top persistent bar, and suppresses secondary content bar',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final testBook = Book(
          id: 'test-reader-toolbar-book',
          title: 'Number the Stars',
          author: 'Lois Lowry',
          language: 'english',
          format: 'epub',
          sourcePath: '/path/to/test.epub',
          chapterCount: 2,
          paragraphCount: 4,
          currentParagraphIndex: 0,
          playbackOffsetMs: 0,
          importedAt: 1000,
          lastReadAt: 1000,
          isRead: false,
          kind: 'book',
          rightsStatus: 'public_domain',
        );
        final ch1 = Chapter(
          id: 'ch-reader-1',
          bookId: 'test-reader-toolbar-book',
          chapterIndex: 0,
          title: 'Introduction',
          textOffset: 0,
          isHidden: false,
        );
        final ch2 = Chapter(
          id: 'ch-reader-2',
          bookId: 'test-reader-toolbar-book',
          chapterIndex: 1,
          title: 'Chapter 2',
          textOffset: 100,
          isHidden: false,
        );
        final p1 = Paragraph(
          id: 'p-reader-1',
          chapterId: 'ch-reader-1',
          bookId: 'test-reader-toolbar-book',
          paragraphIndex: 0,
          content: 'It is hard to believe that I wrote Number the Stars...',
        );
        final p2 = Paragraph(
          id: 'p-reader-2',
          chapterId: 'ch-reader-1',
          bookId: 'test-reader-toolbar-book',
          paragraphIndex: 1,
          content: 'Most books published that long ago have faded...',
        );
        await database.into(database.books).insert(testBook);
        await database.into(database.chapters).insert(ch1);
        await database.into(database.chapters).insert(ch2);
        await database.into(database.paragraphs).insert(p1);
        await database.into(database.paragraphs).insert(p2);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Initially on root Home: All/Books/Podcast switcher and + button are present
        expect(find.byKey(const ValueKey('home-section-selector-desktop')), findsOneWidget);
        expect(find.byKey(const ValueKey('home-add-action-desktop')), findsOneWidget);
        expect(find.byKey(const ValueKey('reader-prev-chapter-button')), findsNothing);
        expect(find.byKey(const ValueKey('reader-next-chapter-button')), findsNothing);

        // Open AlbumScreen by tapping the hero book in the library
        final heroFinder = find.byKey(const ValueKey('home-overview-hero'));
        expect(heroFinder, findsOneWidget);
        await tester.tap(heroFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // From AlbumScreen, tap "Start Reading" button to open BookReaderScreen
        final startReadingFinder = find.byKey(const ValueKey('book-start-reading-button'));
        expect(startReadingFinder, findsOneWidget);
        await tester.tap(startReadingFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // 1. Verify All/Books/Podcast tabs and + button are HIDDEN in top persistent bar
        expect(find.byKey(const ValueKey('home-section-selector-desktop')), findsNothing);
        expect(find.byKey(const ValueKey('home-add-action-desktop')), findsNothing);

        // 2. Verify reader controls are rendered in the top persistent toolbar
        expect(find.byKey(const ValueKey('reader-prev-chapter-button')), findsOneWidget);
        expect(find.byKey(const ValueKey('reader-next-chapter-button')), findsOneWidget);
        expect(find.byKey(const ValueKey('reader-appearance-button')), findsOneWidget);
        expect(find.byKey(const ValueKey('reader-toc-button')), findsOneWidget);
        expect(find.byKey(const ValueKey('reader-player-button')), findsOneWidget);

        // 3. Verify chapter title and progress in top persistent bar
        expect(find.text('Introduction'), findsAtLeastNWidgets(1));
        expect(find.text('1 / 2'), findsOneWidget);

        // 4. Verify no secondary floating bar in content area:
        // On macOS inside AppScaffold, there should only be one TOC button and one appearance button (both in top bar)
        expect(find.byKey(const ValueKey('reader-appearance-button')), findsOneWidget);
        expect(find.byKey(const ValueKey('reader-toc-button')), findsOneWidget);

        // 5. Navigate to Chapter 2 via next chapter button in top persistent bar
        final nextChapterButton = find.byKey(const ValueKey('reader-next-chapter-button'));
        await tester.tap(nextChapterButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        expect(find.text('Chapter 2'), findsAtLeastNWidgets(1));
        expect(find.text('2 / 2'), findsOneWidget);

        // 6. Pop BookReaderScreen via toolbar back button
        final toolbarBack = find.byKey(const ValueKey('macos-back-button'));
        expect(toolbarBack, findsOneWidget);
        await tester.tap(toolbarBack);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // 7. Verify reader controls are removed and AlbumScreen toolbar is restored
        expect(find.byKey(const ValueKey('reader-prev-chapter-button')), findsNothing);
        expect(find.byKey(const ValueKey('reader-next-chapter-button')), findsNothing);
        expect(find.byKey(const ValueKey('macos-book-detail-more-button')), findsOneWidget);

        // 8. Pop AlbumScreen back to Home library root
        await tester.tap(toolbarBack);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // 9. Verify root Home controls are restored
        expect(find.byKey(const ValueKey('home-section-selector-desktop')), findsOneWidget);
        expect(find.byKey(const ValueKey('home-add-action-desktop')), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
