// Run the real Discover route in isolation for simulator layout QA:
// flutter run -t tool/discover_preview.dart -d <simulator-id>
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/presentation/screens/discover/discover_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [
          Locale('en'),
          Locale('zh', 'CN'),
          Locale('ja'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: const bool.fromEnvironment('DISCOVER_DARK')
            ? ThemeMode.dark
            : ThemeMode.light,
        home: const DiscoverScreen(),
      ),
    ),
  );
}
