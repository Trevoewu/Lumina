import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/providers.dart';
import '../../services/incoming_book_import_controller.dart';
import '../screens/album/album_screen.dart';
import '../screens/dictionary/dictionary_screen.dart';
import '../screens/discover/discover_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/me/me_screen.dart';
import '../screens/settings/settings_screen.dart';
import 'design_system/app_navigation_icon.dart';
import 'design_system/app_search_field.dart';
import 'design_system/macos_toolbar_providers.dart';
import 'design_system/macos_window_toolbar.dart';
import 'design_system/page_control_tabs.dart';
import 'design_system/page_toolbar_search.dart';
import '../screens/discover/discover_scope.dart';
import 'mini_player.dart';

/// Scope provided by AppScaffold to allow child widgets (like MiniPlayer)
/// to push sub-pages onto the currently active tab navigator on desktop.
class AppScaffoldScope extends InheritedWidget {
  const AppScaffoldScope({
    super.key,
    required this.pushContent,
    required super.child,
  });

  final Future<T?> Function<T>(Route<T> route) pushContent;

  static AppScaffoldScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScaffoldScope>();

  @override
  bool updateShouldNotify(AppScaffoldScope oldWidget) => false;
}

/// 全局骨架，包含底部导航栏和迷你播放器。
class AppScaffold extends ConsumerStatefulWidget {
  const AppScaffold({super.key});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  int _currentIndex = 0;
  final Set<int> _initializedTabs = {0};
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );

  // macOS sidebar & navigation state
  double _sidebarWidth = 210.0;
  double _lastExpandedWidth = 210.0;
  double _dragWidth = 210.0;
  bool _isSidebarVisible = true;
  bool _isDragging = false;
  final List<int> _tabHistory = [];
  final List<int> _forwardTabHistory = [];
  late final List<_TabNavigatorObserver> _navigatorObservers;

  @override
  void initState() {
    super.initState();
    _navigatorObservers = List.generate(
      4,
      (_) => _TabNavigatorObserver(() {
        if (mounted) setState(() {});
      }),
    );
  }

  bool get _canGoBack {
    final currentNav = _navigatorKeys[_currentIndex].currentState;
    final canPopSubroute = currentNav?.canPop() ?? false;
    return canPopSubroute || _tabHistory.isNotEmpty;
  }

  bool get _canGoForward => _forwardTabHistory.isNotEmpty;

  void _handleBack() {
    final currentNav = _navigatorKeys[_currentIndex].currentState;
    if (currentNav != null && currentNav.canPop()) {
      currentNav.maybePop();
      return;
    }
    if (_tabHistory.isNotEmpty) {
      setState(() {
        final prev = _tabHistory.removeLast();
        _forwardTabHistory.add(_currentIndex);
        _currentIndex = prev;
      });
    }
  }

  void _handleForward() {
    if (_forwardTabHistory.isNotEmpty) {
      setState(() {
        final next = _forwardTabHistory.removeLast();
        _tabHistory.add(_currentIndex);
        _currentIndex = next;
      });
    }
  }

  void _toggleSidebar() {
    setState(() {
      if (_isSidebarVisible) {
        if (_sidebarWidth >= 160.0) {
          _lastExpandedWidth = _sidebarWidth;
        }
        _isSidebarVisible = false;
      } else {
        _isSidebarVisible = true;
        _sidebarWidth = _lastExpandedWidth >= 160.0
            ? _lastExpandedWidth
            : 210.0;
      }
    });
  }

  Widget _rootPageFor(int index) {
    return switch (index) {
      0 => const LibraryScreen(),
      1 => const DiscoverScreen(),
      2 => const DictionaryScreen(),
      3 => const MeScreen(),
      _ => const LibraryScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<IncomingBookImportState>(
      incomingBookImportControllerProvider,
      _handleIncomingBookImport,
    );
    ref.watch(playbackProgressServiceProvider);
    final miniPlayerSuppressed = ref.watch(miniPlayerSuppressedProvider);
    final handlerAsync = ref.watch(luminaAudioHandlerProvider);

    return handlerAsync.when(
      loading: () => _buildScaffold(hasMiniPlayer: false),
      error: (_, _) => _buildScaffold(hasMiniPlayer: false),
      data: (handler) => StreamBuilder<MediaItem?>(
        stream: handler.mediaItem,
        initialData: handler.mediaItem.valueOrNull,
        builder: (context, snapshot) {
          final hasMedia = snapshot.data != null;
          return _buildScaffold(
            hasMiniPlayer: hasMedia && !miniPlayerSuppressed,
          );
        },
      ),
    );
  }

  void _handleIncomingBookImport(
    IncomingBookImportState? previous,
    IncomingBookImportState next,
  ) {
    if (previous?.eventId == next.eventId && previous?.phase == next.phase) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    switch (next.phase) {
      case IncomingBookImportPhase.idle:
        return;
      case IncomingBookImportPhase.importing:
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(minutes: 2),
            content: Text(
              context.tr(
                '正在导入 ${next.fileName ?? 'EPUB'}…',
                'Importing ${next.fileName ?? 'EPUB'}…',
                '${next.fileName ?? 'EPUB'}をインポート中…',
              ),
            ),
          ),
        );
      case IncomingBookImportPhase.succeeded:
        final importedBook = next.result!.book;
        setState(() {
          _initializedTabs.add(0);
          _currentIndex = 0;
        });
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                '已将《${importedBook.title}》导入书架',
                'Imported “${importedBook.title}” to your library',
                '「${importedBook.title}」を本棚にインポートしました',
              ),
            ),
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final navigator = _navigatorKeys[0].currentState;
          if (navigator == null) return;
          navigator.popUntil((route) => route.isFirst);
          navigator.push(
            MaterialPageRoute(builder: (_) => AlbumScreen(book: importedBook)),
          );
        });
      case IncomingBookImportPhase.failed:
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text(
              context.tr(
                '无法导入 ${next.fileName ?? 'EPUB'}',
                'Could not import ${next.fileName ?? 'EPUB'}',
                '${next.fileName ?? 'EPUB'}をインポートできませんでした',
              ),
            ),
          ),
        );
    }
  }

  bool _isMacOS(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  Widget _buildScaffold({required bool hasMiniPlayer}) {
    final isMac = _isMacOS(context);
    final scaffold = isMac
        ? _buildMacOSScaffold(hasMiniPlayer: hasMiniPlayer)
        : _buildMobileScaffold(hasMiniPlayer: hasMiniPlayer);

    if (!isMac) return scaffold;

    // Cmd+, opens Settings; Cmd+[ and Cmd+] navigate back/forward.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            _openSettings,
        const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true): () {
          if (_canGoBack) _handleBack();
        },
        const SingleActivator(LogicalKeyboardKey.bracketRight, meta: true): () {
          if (_canGoForward) _handleForward();
        },
      },
      child: Focus(autofocus: true, child: scaffold),
    );
  }

  void _openSettings() {
    final isMac = _isMacOS(context);
    if (isMac) {
      _navigatorKeys[_currentIndex].currentState?.push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    } else {
      Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
  }

  // ── macOS: top toolbar + resizable sidebar + content ─────────────────────

  Widget _buildMacOSScaffold({required bool hasMiniPlayer}) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    final scaffold = AppScaffoldScope(
      pushContent: <T>(route) {
        final currentNav = _navigatorKeys[_currentIndex].currentState;
        if (currentNav != null) {
          return currentNav.push<T>(route);
        }
        return Navigator.of(context, rootNavigator: true).push<T>(route);
      },
      child: Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Row(
        children: [
          // Collapsible & resizable sidebar
          ClipRect(
            child: AnimatedContainer(
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: _isSidebarVisible ? _sidebarWidth : 0.0,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                child: _isSidebarVisible
                    ? _buildSidebarColumn(theme, accent)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          // Draggable splitter handle extending across the full app window boundary
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) {
                setState(() {
                  _isDragging = true;
                  _dragWidth = _isSidebarVisible ? _sidebarWidth : 0.0;
                });
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragWidth += details.delta.dx;
                  if (_dragWidth < 45.0) {
                    _isSidebarVisible = false;
                  } else {
                    _isSidebarVisible = true;
                    _sidebarWidth = _dragWidth.clamp(80.0, 360.0);
                    if (_sidebarWidth >= 160.0) {
                      _lastExpandedWidth = _sidebarWidth;
                    }
                  }
                });
              },
              onHorizontalDragEnd: (_) {
                setState(() {
                  _isDragging = false;
                  _dragWidth = _sidebarWidth;
                });
              },
              onHorizontalDragCancel: () {
                setState(() {
                  _isDragging = false;
                  _dragWidth = _sidebarWidth;
                });
              },
              onDoubleTap: () {
                setState(() {
                  _isSidebarVisible = true;
                  _sidebarWidth = 210.0;
                  _lastExpandedWidth = 210.0;
                });
              },
              child: Container(
                width: 8.0,
                color: Colors.transparent,
                alignment: Alignment.center,
                child: Container(
                  width: 1.0,
                  color: _isSidebarVisible
                      ? context.appDivider
                      : Colors.transparent,
                ),
              ),
            ),
          ),
          // Persistent Top Control Bar + Content Area
          Expanded(
            child: Column(
              children: [
                Consumer(
                  builder: (context, topBarRef, _) =>
                      _buildPersistentTopBar(theme, accent, topBarRef),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: hasMiniPlayer
                                ? MiniPlayer.navigationGap + MiniPlayer.height
                                : 0,
                          ),
                          child: MacosPersistentToolbarScope(
                            child: _buildContent(),
                          ),
                        ),
                      ),
                      if (hasMiniPlayer)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: MiniPlayer.navigationGap,
                          child: const MiniPlayer(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: scaffold,
    );
  }

  Widget _buildPersistentTopBar(
    ThemeData theme,
    Color accent,
    WidgetRef topBarRef,
  ) {
    final canGoBack = _canGoBack;
    final canGoForward = _canGoForward;
    final customMiddle = topBarRef.watch(macosToolbarMiddleProvider);
    final customTitle = topBarRef.watch(macosToolbarTitleProvider);
    final customTrailing = topBarRef.watch(macosToolbarTrailingProvider);

    return Container(
      height: macosTopControlsReservedHeight,
      color: theme.colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!_isSidebarVisible) ...[
            const SizedBox(width: 78.0),
            MacosToolbarButton(
              key: const ValueKey('macos-sidebar-toggle-button-collapsed'),
              size: 26.0,
              tooltip: '显示侧边栏',
              onPressed: _toggleSidebar,
              child: const SidebarToggleIcon(size: 18.0),
            ),
            const SizedBox(width: 14.0),
            MacosToolbarButton(
              key: const ValueKey('macos-back-button-collapsed'),
              size: 26.0,
              tooltip: '返回',
              onPressed: canGoBack ? _handleBack : null,
              child: const MacosNavArrowIcon(
                direction: MacosNavArrowDirection.left,
                size: 18.0,
              ),
            ),
            const SizedBox(width: 14.0),
            MacosToolbarButton(
              key: const ValueKey('macos-forward-button-collapsed'),
              size: 26.0,
              tooltip: '前进',
              onPressed: canGoForward ? _handleForward : null,
              child: const MacosNavArrowIcon(
                direction: MacosNavArrowDirection.right,
                size: 18.0,
              ),
            ),
            const SizedBox(width: 16.0),
          ] else if (_sidebarWidth < 170.0) ...[
            const SizedBox(width: 8.0),
            MacosToolbarButton(
              key: const ValueKey('macos-back-button-narrow'),
              size: 26.0,
              tooltip: '返回',
              onPressed: canGoBack ? _handleBack : null,
              child: const MacosNavArrowIcon(
                direction: MacosNavArrowDirection.left,
                size: 18.0,
              ),
            ),
            const SizedBox(width: 10.0),
            MacosToolbarButton(
              key: const ValueKey('macos-forward-button-narrow'),
              size: 26.0,
              tooltip: '前进',
              onPressed: canGoForward ? _handleForward : null,
              child: const MacosNavArrowIcon(
                direction: MacosNavArrowDirection.right,
                size: 18.0,
              ),
            ),
            const SizedBox(width: 12.0),
          ],
          Expanded(
            child: customMiddle ??
                ((canGoBack && customTitle != null)
                    ? Container(
                        height: macosTopControlsReservedHeight,
                        padding: const EdgeInsets.only(left: 14.0),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          customTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.normal,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      )
                    : _buildPageControlsForCurrentTab(theme, accent, topBarRef)),
          ),
          if (customTrailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: customTrailing,
            )
          else if (_currentIndex == 0 && !canGoBack)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _buildHomeAddButton(theme, topBarRef),
            ),
        ],
      ),
    );
  }

  Widget _buildPageControlsForCurrentTab(
    ThemeData theme,
    Color accent,
    WidgetRef topBarRef,
  ) {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTopControls(theme, accent, topBarRef);
      case 1:
        return _buildDiscoverTopControls(theme, accent, topBarRef);
      case 2:
        return _buildDictionaryTopControls(theme, accent);
      case 3:
        return _buildMeTopControls(theme, accent);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHomeTopControls(
    ThemeData theme,
    Color accent,
    WidgetRef topBarRef,
  ) {
    final currentSection = topBarRef.watch(homeSectionProvider);

    return PageControlTabs<HomeSection>(
      key: const ValueKey('home-section-selector-desktop'),
      height: macosTopControlsReservedHeight,
      padding: const EdgeInsets.only(left: 12.0),
      labels: {
        HomeSection.all: context.tr('全部', 'All', 'すべて'),
        HomeSection.books: context.tr('书籍', 'Books', '本'),
        HomeSection.podcasts: 'Podcast',
      },
      selected: currentSection,
      onSelected: (section) {
        ref.read(homeSectionProvider.notifier).updateValue(section);
      },
      itemKey: (section) => ValueKey('home-section-${section.name}'),
    );
  }

  Widget _buildHomeAddButton(ThemeData theme, WidgetRef topBarRef) {
    final currentSection = topBarRef.watch(homeSectionProvider);
    final onAddAction = topBarRef.watch(homeAddActionProvider);

    return MacosToolbarButton(
      key: const ValueKey('home-add-action-desktop'),
      size: 26.0,
      tooltip: currentSection == HomeSection.podcasts
          ? context.tr('添加 Podcast', 'Add podcast', 'ポッドキャストを追加')
          : currentSection == HomeSection.books
          ? context.tr('导入书籍', 'Import book', '本をインポート')
          : context.tr('添加内容', 'Add content', 'コンテンツを追加'),
      onPressed: onAddAction,
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedAdd01,
        size: 20.0,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildDiscoverTopControls(
    ThemeData theme,
    Color accent,
    WidgetRef topBarRef,
  ) {
    final currentScope = topBarRef.watch(discoverScopeProvider);
    final searchController = topBarRef.watch(discoverSearchControllerProvider);
    final searching = topBarRef.watch(discoverSearchingProvider);
    final onSearch = topBarRef.watch(discoverSearchHandlerProvider);

    final tabs = PageControlTabs<DiscoverScope>(
      key: const ValueKey('discover-scope-selector-desktop'),
      height: macosTopControlsReservedHeight,
      padding: const EdgeInsets.only(left: 12.0),
      labels: {
        for (final scope in [
          DiscoverScope.onlineBooks,
          DiscoverScope.audiobooks,
          DiscoverScope.podcasts,
          DiscoverScope.library,
        ])
          scope: scope.label(context),
      },
      selected: currentScope,
      itemKey: (scope) => ValueKey('discover-scope-${scope.name}'),
      onSelected: (scope) {
        ref.read(discoverScopeProvider.notifier).updateValue(scope);
      },
    );

    if (searchController == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: tabs),
        ],
      );
    }

    Widget buildSearch(bool autofocus) => AppSearchField(
      fieldKey: const ValueKey('discover-search-field-desktop'),
      controller: searchController,
      onChanged: (val) {
        if (onSearch != null) onSearch();
      },
      autofocus: autofocus,
      compact: true,
      autocorrect: currentScope != DiscoverScope.podcasts,
      enableSuggestions: currentScope != DiscoverScope.podcasts,
      loading: searching,
      onSubmitted: (_) {
        if (onSearch != null) onSearch();
      },
      onSearch: onSearch ?? () {},
      hintText: currentScope.hintText(context),
    );

    return PageToolbarSearch(
      tabs: tabs,
      searchBuilder: buildSearch,
    );
  }

  Widget _buildDictionaryTopControls(ThemeData theme, Color accent) {
    return Container(
      height: macosTopControlsReservedHeight,
      padding: const EdgeInsets.only(left: 14.0),
      alignment: Alignment.centerLeft,
      child: Text(
        context.tr('查词', 'Dictionary', '辞書'),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.normal,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildMeTopControls(ThemeData theme, Color accent) {
    return Container(
      height: macosTopControlsReservedHeight,
      padding: const EdgeInsets.only(left: 14.0),
      alignment: Alignment.centerLeft,
      child: Text(
        context.tr('我的', 'Me', 'マイページ'),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.normal,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildSidebarColumn(ThemeData theme, Color accent) {
    final isExtended = _sidebarWidth >= 160.0;

    return SizedBox(
      width: _sidebarWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: macosTopControlsReservedHeight,
            padding: const EdgeInsets.only(left: 78.0, right: 8.0),
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MacosToolbarButton(
                  key: const ValueKey('macos-sidebar-toggle-button'),
                  size: 26.0,
                  tooltip: '隐藏侧边栏',
                  onPressed: _toggleSidebar,
                  child: const SidebarToggleIcon(size: 18.0),
                ),
                if (_sidebarWidth >= 170.0) ...[
                  const SizedBox(width: 14.0),
                  MacosToolbarButton(
                    key: const ValueKey('macos-back-button'),
                    size: 26.0,
                    tooltip: '返回',
                    onPressed: _canGoBack ? _handleBack : null,
                    child: const MacosNavArrowIcon(
                      direction: MacosNavArrowDirection.left,
                      size: 18.0,
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  MacosToolbarButton(
                    key: const ValueKey('macos-forward-button'),
                    size: 26.0,
                    tooltip: '前进',
                    onPressed: _canGoForward ? _handleForward : null,
                    child: const MacosNavArrowIcon(
                      direction: MacosNavArrowDirection.right,
                      size: 18.0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: _buildNavigationRail(theme, accent),
            ),
          ),
          Divider(height: 1, thickness: 1, color: context.appDivider),
          _buildBottomMeCard(theme, accent, isExtended),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(ThemeData theme, Color accent) {
    final isExtended = _sidebarWidth >= 160.0;

    return NavigationRail(
      selectedIndex: _currentIndex < 3 ? _currentIndex : null,
      onDestinationSelected: _onDestinationSelected,
      extended: isExtended,
      minWidth: 80.0,
      minExtendedWidth: isExtended ? _sidebarWidth : 160.0,
      labelType: NavigationRailLabelType.none,
      backgroundColor: theme.colorScheme.surface,
      indicatorColor: accent.withValues(alpha: 0.12),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      selectedIconTheme: IconThemeData(color: accent),
      unselectedIconTheme: IconThemeData(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      selectedLabelTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: accent,
        fontWeight: FontWeight.normal,
      ),
      unselectedLabelTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      leading: const SizedBox(height: 8.0),
      destinations: [
        NavigationRailDestination(
          icon: const AppNavigationIcon(AppNavigationSymbol.home),
          label: Text(context.tr('主页', 'Home', 'ホーム')),
        ),
        NavigationRailDestination(
          icon: const AppNavigationIcon(AppNavigationSymbol.discover),
          label: Text(context.tr('发现', 'Discover', '発見')),
        ),
        NavigationRailDestination(
          icon: const AppNavigationIcon(AppNavigationSymbol.dictionary),
          label: Text(context.tr('查词', 'Dictionary', '辞書')),
        ),
      ],
    );
  }

  Widget _buildBottomMeCard(ThemeData theme, Color accent, bool isExtended) {
    final isSelected = _currentIndex == 3;

    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: isExtended ? _sidebarWidth : 80.0,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isExtended ? 12.0 : 8.0,
            vertical: 8.0,
          ),
          child: _MacosProfileTile(
            key: const ValueKey('sidebar-me-profile-card'),
            isSelected: isSelected,
            isExtended: isExtended,
            accentColor: accent,
            userName: 'Trevor',
            planName: 'Free',
            onTap: () => _onDestinationSelected(3),
          ),
        ),
      ),
    );
  }

  // ── iOS / other: bottom CNTabBar (unchanged) ──────────────────────────────

  Widget _buildMobileScaffold({required bool hasMiniPlayer}) {
    return Scaffold(
      extendBody: true,
      // The mini player floats inside the body rather than sitting in a Column
      // above the bar, so the bar stays a single widget in its slot.
      body: Builder(
        builder: (context) {
          // extendBody reports the tab bar's height here as bottom padding.
          final barInset = MediaQuery.paddingOf(context).bottom;
          final media = MediaQuery.of(context);
          // CNTabBar 1.6 reserves 14 pt above its native iOS bar for the
          // selection animation. Measure spacing from the visible bar edge.
          final nativeTopRoom =
              defaultTargetPlatform == TargetPlatform.iOS &&
                  PlatformVersion.supportsLiquidGlass
              ? 14.0
              : 0.0;
          final playerBottom =
              barInset + MiniPlayer.navigationGap - nativeTopRoom;

          return Stack(
            children: [
              Positioned.fill(
                child: MediaQuery(
                  data: media.copyWith(
                    padding: media.padding.copyWith(
                      bottom: hasMiniPlayer
                          ? playerBottom + MiniPlayer.height
                          : barInset,
                    ),
                  ),
                  child: _buildContent(),
                ),
              ),
              if (hasMiniPlayer)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: playerBottom,
                  child: const MiniPlayer(),
                ),
            ],
          );
        },
      ),
      // CNTabBar embeds a UIKit tab bar on iOS 26 and falls back to a Flutter
      // CupertinoTabBar elsewhere. Both paths use the same HugeIcons assets.
      bottomNavigationBar: CNTabBar(
        currentIndex: _currentIndex,
        onTap: _onDestinationSelected,
        tint: Theme.of(context).colorScheme.primary,
        items: [
          CNTabBarItem(
            label: context.tr('主页', 'Home', 'ホーム'),
            imageAsset: const CNImageAsset(
              'assets/ui_icons/home.png',
              size: 25,
            ),
          ),
          CNTabBarItem(
            label: context.tr('发现', 'Discover', '発見'),
            imageAsset: const CNImageAsset(
              'assets/ui_icons/discover.png',
              size: 25,
            ),
          ),
          CNTabBarItem(
            label: context.tr('查词', 'Dictionary', '辞書'),
            imageAsset: const CNImageAsset(
              'assets/ui_icons/dictionary.png',
              size: 25,
            ),
          ),
          CNTabBarItem(
            label: context.tr('我的', 'Me', 'マイページ'),
            imageAsset: const CNImageAsset('assets/ui_icons/me.png', size: 25),
          ),
        ],
      ),
    );
  }

  // ── Shared: tab content (IndexedStack + per-tab navigators) ───────────────

  Widget _buildContent() {
    return IndexedStack(
      key: const ValueKey('app-content-layer'),
      index: _currentIndex,
      children: List.generate(
        _navigatorKeys.length,
        (index) => _initializedTabs.contains(index)
            ? NavigatorPopHandler<void>(
                enabled: index == _currentIndex,
                onPopWithResult: (_) {
                  _navigatorKeys[index].currentState?.maybePop();
                },
                child: Navigator(
                  key: _navigatorKeys[index],
                  observers: [_navigatorObservers[index]],
                  onGenerateRoute: (_) =>
                      MaterialPageRoute(builder: (_) => _rootPageFor(index)),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  void _onDestinationSelected(int index) {
    if (index == _currentIndex) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _tabHistory.add(_currentIndex);
      _forwardTabHistory.clear();
      _initializedTabs.add(index);
      _currentIndex = index;
    });
  }
}

/// Observer tracking route push/pop/replace across tab navigators to update
/// toolbar back/forward availability.
class _TabNavigatorObserver extends NavigatorObserver {
  _TabNavigatorObserver(this.onChanged);

  final VoidCallback onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged());
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged());
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged());
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged());
  }
}

/// macOS sidebar bottom user profile card matching the system UI.
class _MacosProfileTile extends StatefulWidget {
  const _MacosProfileTile({
    super.key,
    required this.isSelected,
    required this.isExtended,
    required this.accentColor,
    required this.userName,
    required this.planName,
    required this.onTap,
  });

  final bool isSelected;
  final bool isExtended;
  final Color accentColor;
  final String userName;
  final String planName;
  final VoidCallback onTap;

  @override
  State<_MacosProfileTile> createState() => _MacosProfileTileState();
}

class _MacosProfileTileState extends State<_MacosProfileTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    Color backgroundColor = Colors.transparent;
    if (widget.isSelected) {
      backgroundColor = widget.accentColor.withValues(alpha: 0.12);
    } else if (_isHovered) {
      backgroundColor = onSurface.withValues(alpha: 0.05);
    }

    // Circular avatar: green background with cream flower icon
    final avatar = Container(
      width: 32.0,
      height: 32.0,
      decoration: const BoxDecoration(
        color: Color(0xFF5E804F),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const HugeIcon(
        icon: HugeIcons.strokeRoundedFlower,
        size: 18.0,
        color: Color(0xFFEBE6DC),
      ),
    );

    if (!widget.isExtended) {
      return Tooltip(
        message: '${widget.userName} · ${widget.planName}',
        waitDuration: const Duration(milliseconds: 500),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 44.0,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(10.0),
              ),
              alignment: Alignment.center,
              child: avatar,
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44.0,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 10.0),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: widget.userName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.normal,
                                color: widget.isSelected
                                    ? widget.accentColor
                                    : onSurface,
                              ),
                            ),
                            TextSpan(
                              text: ' · ${widget.planName}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: onSurfaceVariant,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowDown01,
                      size: 14.0,
                      color: onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6.0),
              // Download tray button
              Tooltip(
                message: context.tr('离线下载', 'Downloads', 'ダウンロード'),
                waitDuration: const Duration(milliseconds: 600),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedDownload01,
                        size: 18.0,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
