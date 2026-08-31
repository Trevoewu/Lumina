import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cupertino_native_better/cupertino_native.dart';

import '../../core/app_localizations.dart';
import '../../core/providers.dart';
import '../../services/incoming_book_import_controller.dart';
import '../screens/album/album_screen.dart';
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

  Widget _buildScaffold({required bool hasMiniPlayer}) {
    return Scaffold(
      extendBody: true,
      // The mini player floats inside the body rather than sitting in a Column
      // above the bar, so the bar stays a single widget in its slot.
      body: Builder(
        builder: (context) {
          // extendBody reports the tab bar's height here as bottom padding.
          final barInset = MediaQuery.paddingOf(context).bottom;
          final media = MediaQuery.of(context);

          return Stack(
            children: [
              Positioned.fill(
                child: MediaQuery(
                  data: media.copyWith(
                    padding: media.padding.copyWith(
                      bottom:
                          barInset + (hasMiniPlayer ? MiniPlayer.height : 0),
                    ),
                  ),
                  child: IndexedStack(
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
                                onGenerateRoute: (_) => MaterialPageRoute(
                                  builder: (_) => _rootPageFor(index),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              if (hasMiniPlayer)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: barInset,
                  child: const MiniPlayer(),
                ),
            ],
          );
        },
      ),
      // CNTabBar embeds a UIKit tab bar on iOS 26 and falls back to a Flutter
      // CupertinoTabBar elsewhere. Each item carries both an SF Symbol (used
      // natively) and a customIcon (used by the fallback).
      bottomNavigationBar: CNTabBar(
        currentIndex: _currentIndex,
        onTap: _onDestinationSelected,
        tint: Theme.of(context).colorScheme.primary,
        items: [
          CNTabBarItem(
            label: context.tr('主页', 'Home', 'ホーム'),
            icon: const CNSymbol('house.fill'),
            customIcon: Icons.home_rounded,
          ),
          CNTabBarItem(
            label: context.tr('查词', 'Dictionary', '辞書'),
            icon: const CNSymbol('character.book.closed.fill'),
            customIcon: Icons.find_in_page_rounded,
          ),
          CNTabBarItem(
            label: context.tr('我的', 'Me', 'マイページ'),
            icon: const CNSymbol('person.fill'),
            customIcon: Icons.person_rounded,
          ),
        ],
      ),
    );
  }

  void _onDestinationSelected(int index) {
    if (index == _currentIndex) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _initializedTabs.add(index);
      _currentIndex = index;
    });
  }
}
