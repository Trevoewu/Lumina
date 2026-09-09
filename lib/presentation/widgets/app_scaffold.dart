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
import 'design_system/macos_window_toolbar.dart';
import 'design_system/macos_page_toolbar.dart';
import 'mini_player.dart';

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
    final handlerAsync = ref.watch(luminaAudioHandlerProvider);

    return handlerAsync.when(
      loading: () => _buildScaffold(hasMiniPlayer: false),
      error: (_, _) => _buildScaffold(hasMiniPlayer: false),
      data: (handler) => StreamBuilder<MediaItem?>(
        stream: handler.mediaItem,
        initialData: handler.mediaItem.valueOrNull,
        builder: (context, snapshot) {
          return _buildScaffold(hasMiniPlayer: snapshot.data != null);
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

    final scaffold = Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Base layout: full-height Row with sidebar, full-height 1px divider, and content
          Positioned.fill(
            child: Row(
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
                            ? AppColors.divider
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
                // Page controls share the window toolbar row above the content.
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: 0,
                            bottom: hasMiniPlayer
                                ? MiniPlayer.navigationGap + MiniPlayer.height
                                : 0,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                MacosPageToolbarScope(
                                  leadingInset:
                                      (macosTopControlsReservedWidth +
                                              16 -
                                              (MediaQuery.sizeOf(
                                                    context,
                                                  ).width -
                                                  constraints.maxWidth))
                                          .clamp(
                                            0.0,
                                            macosTopControlsReservedWidth + 16,
                                          ),
                                  child: Builder(
                                    builder: (context) =>
                                        _buildContent(context),
                                  ),
                                ),
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
          // Top window toolbar with traffic lights clearance and navigation controls
          Positioned(
            top: 0,
            left: 0,
            width: macosTopControlsReservedWidth + 16,
            child: MacosWindowToolbar(
              isSidebarVisible: _isSidebarVisible,
              onToggleSidebar: _toggleSidebar,
              canGoBack: _canGoBack,
              onBack: _handleBack,
              canGoForward: _canGoForward,
              onForward: _handleForward,
            ),
          ),
        ],
      ),
    );

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: scaffold,
    );
  }

  Widget _buildSidebarColumn(ThemeData theme, Color accent) {
    final isExtended = _sidebarWidth >= 160.0;

    return SizedBox(
      width: _sidebarWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: _buildNavigationRail(theme, accent),
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppColors.divider),
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
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      leading: const SizedBox(height: 44.0),
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

  Widget _buildContent([BuildContext? contentContext]) {
    final context = contentContext ?? this.context;
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
                child: Padding(
                  padding: EdgeInsets.only(
                    top:
                        MacosPageToolbarScope.maybeOf(context) != null &&
                            (index > 1 ||
                                (_navigatorKeys[index].currentState?.canPop() ??
                                    false))
                        ? macosTopControlsReservedHeight
                        : 0,
                  ),
                  child: Navigator(
                    key: _navigatorKeys[index],
                    observers: [_navigatorObservers[index]],
                    onGenerateRoute: (_) =>
                        MaterialPageRoute(builder: (_) => _rootPageFor(index)),
                  ),
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
                                fontWeight: FontWeight.w600,
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
