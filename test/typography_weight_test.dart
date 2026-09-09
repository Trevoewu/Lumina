import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:lumina/presentation/widgets/design_system/page_control_tabs.dart';
import 'package:lumina/presentation/widgets/design_system/settings_components.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('controls and settings use regular weight (dark: $dark)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
          home: Scaffold(
            body: Column(
              children: [
                PageControlTabs<int>(
                  labels: const {0: 'Books', 1: 'Podcasts'},
                  selected: 0,
                  onSelected: (_) {},
                ),
                SettingValueRow(
                  icon: AppIcons.settings02,
                  title: 'Provider name',
                  subtitle: 'Provider description',
                  value: '20 MB',
                  badge: 'Ready',
                ),
                FilledButton(onPressed: () {}, child: const Text('Save')),
                OutlinedButton(onPressed: () {}, child: const Text('Download')),
                TextButton(onPressed: () {}, child: const Text('Cancel')),
                ElevatedButton(onPressed: () {}, child: const Text('Confirm')),
                const Chip(label: Text('Tag')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FontWeight? weight(String label) {
        final finder = find.text(label);
        final text = tester.widget<Text>(finder);
        return DefaultTextStyle.of(
          tester.element(finder),
        ).style.merge(text.style).fontWeight;
      }

      for (final label in [
        'Podcasts',
        'Provider name',
        'Provider description',
        '20 MB',
        'Ready',
        'Save',
        'Download',
        'Cancel',
        'Confirm',
        'Tag',
      ]) {
        expect(weight(label), FontWeight.normal, reason: label);
      }
      expect(weight('Books'), FontWeight.w800);
    });
  }
}
