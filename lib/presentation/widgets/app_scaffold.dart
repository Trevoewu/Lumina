import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/app_localizations.dart';
import '../../core/providers.dart';
import '../screens/dictionary/dictionary_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/me/me_screen.dart';
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
    3,
    (_) => GlobalKey<NavigatorState>(),
  );

  Widget _rootPageFor(int index) {
    return switch (index) {
      0 => const LibraryScreen(),
      1 => const DictionaryScreen(),
      2 => const MeScreen(),
      _ => const LibraryScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
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

  Widget _buildScaffold({required bool hasMiniPlayer}) {
    return Scaffold(
      body: IndexedStack(
        key: const ValueKey('app-content-layer'),
        index: _currentIndex,
        children: List.generate(
          _navigatorKeys.length,
          (index) => _initializedTabs.contains(index)
              ? Navigator(
                  key: _navigatorKeys[index],
                  onGenerateRoute: (_) =>
                      MaterialPageRoute(builder: (_) => _rootPageFor(index)),
                )
              : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasMiniPlayer) const MiniPlayer(),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: NavigationBar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.86),
                elevation: 0,
                height: 46,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  if (index == _currentIndex) {
                    _navigatorKeys[index].currentState?.popUntil(
                      (route) => route.isFirst,
                    );
                    return;
                  }
                  setState(() {
                    _initializedTabs.add(index);
                    _currentIndex = index;
                  });
                },
                destinations: [
                  NavigationDestination(
                    icon: const _NavigationSvgIcon(
                      key: ValueKey('home-navigation-icon'),
                      assetName: 'assets/navigation_icons/home_rounded.svg',
                    ),
                    selectedIcon: const _NavigationSvgIcon(
                      key: ValueKey('home-navigation-active-icon'),
                      assetName: 'assets/navigation_icons/home_rounded.svg',
                    ),
                    label: context.tr('主页', 'Home'),
                  ),
                  NavigationDestination(
                    icon: const _NavigationSvgIcon(
                      key: ValueKey('dictionary-navigation-icon'),
                      assetName: 'assets/navigation_icons/dictionary.svg',
                    ),
                    selectedIcon: const _NavigationSvgIcon(
                      key: ValueKey('dictionary-navigation-active-icon'),
                      assetName: 'assets/navigation_icons/dictionary.svg',
                    ),
                    label: context.tr('查词', 'Dictionary'),
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Me',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationSvgIcon extends StatelessWidget {
  final String assetName;

  const _NavigationSvgIcon({super.key, required this.assetName});

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    return SvgPicture.asset(
      assetName,
      width: iconTheme.size ?? 24,
      height: iconTheme.size ?? 24,
      colorFilter: ColorFilter.mode(
        iconTheme.color ?? Theme.of(context).colorScheme.onSurface,
        BlendMode.srcIn,
      ),
    );
  }
}
