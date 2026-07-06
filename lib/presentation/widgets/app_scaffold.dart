import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';

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
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              key: const ValueKey('app-content-layer'),
              index: _currentIndex,
              children: List.generate(
                _navigatorKeys.length,
                (index) => _initializedTabs.contains(index)
                    ? Navigator(
                        key: _navigatorKeys[index],
                        onGenerateRoute: (_) => MaterialPageRoute(
                          builder: (_) => _rootPageFor(index),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          if (hasMiniPlayer)
            const Positioned(left: 0, right: 0, bottom: 0, child: MiniPlayer()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
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
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: context.tr('主页', 'Home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book_outlined),
            activeIcon: const Icon(Icons.menu_book),
            label: context.tr('查词', 'Dictionary'),
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
