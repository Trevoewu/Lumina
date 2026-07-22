import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_colors.dart';
import 'core/app_preferences.dart';
import 'core/appearance.dart';
import 'core/theme.dart';
import 'presentation/widgets/app_scaffold.dart';
import 'services/app_log_service.dart';
import 'tts/provider_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = AppLogService.instance;
  await logger.initialize();

  final flutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLogger.error(
      'Flutter',
      'Flutter 框架异常',
      error: details.exception,
      stackTrace: details.stack,
    );
    flutterErrorHandler?.call(details);
  };
  final platformErrorHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLogger.error(
      'Platform',
      '未处理的平台异常',
      error: error,
      stackTrace: stackTrace,
    );
    return platformErrorHandler?.call(error, stackTrace) ?? false;
  };

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
    Future.microtask(
      () => ref.read(activeTtsProviderIdProvider.notifier).load(),
    );
    Future.microtask(() => ref.read(appPreferencesProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceControllerProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final darkTheme = AppTheme.darkTheme(
      accentColor: appearance.accentColor,
      readingFontFamily: appearance.fontOption.fontFamily,
      readingFontFamilyFallback: appearance.fontOption.fontFamilyFallback,
    );
    final lightTheme = AppTheme.lightTheme(
      accentColor: appearance.accentColor,
      readingFontFamily: appearance.fontOption.fontFamily,
      readingFontFamilyFallback: appearance.fontOption.fontFamilyFallback,
    );

    return MaterialApp(
      title: 'Lumina',
      debugShowCheckedModeBanner: false,
      locale: preferences.locale,
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: preferences.themeMode,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: _RelativeTextScaler(
              media.textScaler,
              appearance.fontScale,
            ),
          ),
          child: _MacWindowInset(child: child ?? const SizedBox.shrink()),
        );
      },
      home: const AppScaffold(),
    );
  }
}

/// Applies Lumina's reading-size preference without discarding the platform's
/// accessibility text scaling (including nonlinear scaling on newer systems).
class _RelativeTextScaler extends TextScaler {
  final TextScaler systemScaler;
  final double factor;

  const _RelativeTextScaler(this.systemScaler, this.factor);

  @override
  double scale(double fontSize) => systemScaler.scale(fontSize) * factor;

  @override
  double get textScaleFactor => systemScaler.scale(1) * factor;

  @override
  bool operator ==(Object other) =>
      other is _RelativeTextScaler &&
      other.systemScaler == systemScaler &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(systemScaler, factor);
}

class _MacWindowInset extends StatelessWidget {
  final Widget child;

  const _MacWindowInset({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return child;

    return ColoredBox(
      color: context.appBackground,
      child: Padding(padding: const EdgeInsets.only(top: 28), child: child),
    );
  }
}
