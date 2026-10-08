import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two shelves in the Library tab.
enum LibrarySection { books, podcasts }

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

/// Active shelf in the Library tab.
final librarySectionProvider =
    NotifierProvider<AppToolbarStateNotifier<LibrarySection>, LibrarySection>(
      () => AppToolbarStateNotifier<LibrarySection>(LibrarySection.books),
    );

/// Callback to trigger the Add Action from the persistent top bar in Home.
final homeAddActionProvider =
    NotifierProvider<AppToolbarStateNotifier<VoidCallback?>, VoidCallback?>(
      () => AppToolbarStateNotifier<VoidCallback?>(null),
    );

/// Callback to trigger the Add Action from the persistent top bar in Library.
final libraryAddActionProvider =
    NotifierProvider<AppToolbarStateNotifier<VoidCallback?>, VoidCallback?>(
      () => AppToolbarStateNotifier<VoidCallback?>(null),
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
