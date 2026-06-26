import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_colors.dart';
import 'core/theme.dart';
import 'presentation/widgets/app_scaffold.dart';

void main() {
  runApp(const ProviderScope(child: LuminaApp()));
}

class LuminaApp extends StatelessWidget {
  const LuminaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumina',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // 强制深色模式
      builder: (context, child) =>
          _MacWindowInset(child: child ?? const SizedBox.shrink()),
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
