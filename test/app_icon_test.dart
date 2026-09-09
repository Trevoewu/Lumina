import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/settings/appearance_screen.dart';
import 'package:lumina/presentation/screens/settings/settings_screen.dart';
import 'package:lumina/services/app_icon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelAppIconGateway.channel, null);
  });

  test('app icon channel reads and changes the selected icon', () async {
    var selectedId = 'a1';
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelAppIconGateway.channel, (
          call,
        ) async {
          calls.add(call);
          return switch (call.method) {
            'isSupported' => true,
            'getIcon' => selectedId,
            'setIcon' =>
              selectedId =
                  (call.arguments as Map<Object?, Object?>)['iconId']!
                      as String,
            _ => throw MissingPluginException(),
          };
        });

    const gateway = MethodChannelAppIconGateway();
    expect(await gateway.isSupported(), isTrue);
    expect(await gateway.currentIconId(), 'a1');
    await gateway.setIcon('c2');
    expect(await gateway.currentIconId(), 'c2');
    expect(calls.map((call) => call.method), [
      'isSupported',
      'getIcon',
      'setIcon',
      'getIcon',
    ]);
  });

  test(
    'app icon gateway handles unsupported platforms and invalid ids',
    () async {
      const gateway = MethodChannelAppIconGateway();
      expect(await gateway.isSupported(), isFalse);
      expect(await gateway.currentIconId(), 'a1');
      expect(() => gateway.setIcon('unknown'), throwsArgumentError);
    },
  );

  test('all seven icon previews and native resources exist', () {
    expect(appIconOptions.map((option) => option.id), [
      'a1',
      'default',
      'a2',
      'b1',
      'b2',
      'c1',
      'c2',
    ]);
    for (final option in appIconOptions) {
      expect(File(option.assetPath).existsSync(), isTrue, reason: option.id);
    }

    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    for (final suffix in const ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']) {
      expect(manifest, contains('.Launcher$suffix'));
      expect(
        Directory(
          'ios/Runner/Assets.xcassets/AppIcon$suffix.appiconset',
        ).existsSync(),
        isTrue,
      );
    }
    expect(manifest, contains('.LauncherDefault'));

    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final id in const ['a1', 'a2', 'b1', 'b2', 'c1', 'c2']) {
      expect(infoPlist, contains('<key>$id</key>'));
    }
  });

  testWidgets('icon picker switches among all seven previews', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeAppIconGateway(selectedId: 'default');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appIconGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const AppearanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('app-icon-default')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    for (final option in appIconOptions) {
      expect(find.byKey(ValueKey('app-icon-${option.id}')), findsOneWidget);
    }

    await tester.ensureVisible(find.byKey(const ValueKey('app-icon-b2')));
    await tester.tap(find.byKey(const ValueKey('app-icon-b2')));
    await tester.pumpAndSettle();

    expect(gateway.selectedId, 'b2');
    expect(gateway.setCalls, ['b2']);
    expect(find.text('App icon changed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings reaches the app icon picker through appearance', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final gateway = _FakeAppIconGateway(selectedId: 'default');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          appIconGatewayProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    final appearanceRow = find.byKey(const ValueKey('appearance-settings'));
    await tester.scrollUntilVisible(
      appearanceRow,
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(appearanceRow);
    await tester.pumpAndSettle();

    expect(find.byType(AppearanceScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('app-icon-default')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('app-icon-default')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon picker disables changes on unsupported platforms', (
    tester,
  ) async {
    final gateway = _FakeAppIconGateway(
      supported: false,
      selectedId: 'default',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appIconGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: const AppearanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('app-icon-a1')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('does not support changing the launcher icon'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('app-icon-a1')));
    await tester.pump();
    expect(gateway.setCalls, isEmpty);
  });
}

class _FakeAppIconGateway implements AppIconGateway {
  final bool supported;
  String selectedId;
  final List<String> setCalls = [];

  _FakeAppIconGateway({this.supported = true, required this.selectedId});

  @override
  Future<String> currentIconId() async => selectedId;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<void> setIcon(String iconId) async {
    setCalls.add(iconId);
    selectedId = iconId;
  }
}
