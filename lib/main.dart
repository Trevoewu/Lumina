import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_colors.dart';
import 'core/appearance.dart';
import 'core/theme.dart';
import 'presentation/widgets/app_scaffold.dart';

void main() {
  runApp(const ProviderScope(child: LuminaApp()));
}

class LuminaApp extends ConsumerStatefulWidget {
  const LuminaApp({super.key});

  @override
  ConsumerState<LuminaApp> createState() => _LuminaAppState();
}

class _LuminaAppState extends ConsumerState<LuminaApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(appearanceControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceControllerProvider);
    final theme = AppTheme.darkTheme(
      accentColor: appearance.accentColor,
      fontFamily: appearance.fontOption.fontFamily,
    );

    return MaterialApp(
      title: 'Lumina',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark, // 强制深色模式
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(appearance.fontScale),
          ),
          child: _MacWindowInset(child: child ?? const SizedBox.shrink()),
        );
      },
      home: const AppScaffold(),
    );
  }
}

class _MacWindowInset extends StatelessWidget {
  final Widget child;

  const _MacWindowInset({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return child;

    return ColoredBox(
      color: AppColors.background,
      child: Padding(padding: const EdgeInsets.only(top: 28), child: child),
    );
  }
}
