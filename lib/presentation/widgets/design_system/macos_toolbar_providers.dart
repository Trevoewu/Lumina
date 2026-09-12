import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../screens/discover/discover_scope.dart';

/// Navigation section in the Home (Library) tab.
enum HomeSection { all, books, podcasts }

class AppToolbarStateNotifier<T> extends Notifier<T> {
  AppToolbarStateNotifier(this._initial);
  final T _initial;

  @override
  T build() => _initial;

  void updateValue(T value) {
    if (!ref.mounted) return;
    state = value;
  }
}

/// Active section in Home.
final homeSectionProvider =
    NotifierProvider<AppToolbarStateNotifier<HomeSection>, HomeSection>(
      () => AppToolbarStateNotifier<HomeSection>(HomeSection.all),
    );

/// Callback to trigger the Add Action from the persistent top bar in Home.
final homeAddActionProvider =
    NotifierProvider<AppToolbarStateNotifier<VoidCallback?>, VoidCallback?>(
      () => AppToolbarStateNotifier<VoidCallback?>(null),
    );

/// Active search scope in Discover.
final discoverScopeProvider =
    NotifierProvider<AppToolbarStateNotifier<DiscoverScope>, DiscoverScope>(
      () => AppToolbarStateNotifier<DiscoverScope>(DiscoverScope.onlineBooks),
    );

/// Search controller registered by DiscoverScreen.
final discoverSearchControllerProvider =
    NotifierProvider<
      AppToolbarStateNotifier<TextEditingController?>,
      TextEditingController?
    >(() => AppToolbarStateNotifier<TextEditingController?>(null));

/// Search trigger callback registered by DiscoverScreen.
final discoverSearchHandlerProvider =
    NotifierProvider<AppToolbarStateNotifier<VoidCallback?>, VoidCallback?>(
      () => AppToolbarStateNotifier<VoidCallback?>(null),
    );

/// Whether a search is in progress in Discover.
final discoverSearchingProvider =
    NotifierProvider<AppToolbarStateNotifier<bool>, bool>(
      () => AppToolbarStateNotifier<bool>(false),
    );

/// Optional title displayed in the persistent top bar by sub-pages.
final macosToolbarTitleProvider =
    NotifierProvider<AppToolbarStateNotifier<String?>, String?>(
      () => AppToolbarStateNotifier<String?>(null),
    );

/// Optional middle widget displayed in the persistent top bar by sub-pages (e.g. reader controls).
final macosToolbarMiddleProvider =
    NotifierProvider<AppToolbarStateNotifier<Widget?>, Widget?>(
      () => AppToolbarStateNotifier<Widget?>(null),
    );

/// Optional trailing action widget displayed in the persistent top bar.
final macosToolbarTrailingProvider =
    NotifierProvider<AppToolbarStateNotifier<Widget?>, Widget?>(
      () => AppToolbarStateNotifier<Widget?>(null),
    );

/// Whether the bottom MiniPlayer should be suppressed (e.g. when viewing PlayerScreen).
final miniPlayerSuppressedProvider =
    NotifierProvider<AppToolbarStateNotifier<bool>, bool>(
      () => AppToolbarStateNotifier<bool>(false),
    );

/// InheritedWidget indicating that the top control bar is persistently
/// rendered above the content area at the AppScaffold level.
class MacosPersistentToolbarScope extends InheritedWidget {
  const MacosPersistentToolbarScope({super.key, required super.child});

  static bool hasToolbar(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MacosPersistentToolbarScope>() !=
      null;

  @override
  bool updateShouldNotify(MacosPersistentToolbarScope oldWidget) => false;
}
