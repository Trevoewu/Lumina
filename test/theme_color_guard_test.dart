import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation code does not bypass the active accent color', () {
    final forbiddenPatterns = <RegExp>[
      RegExp(r'AppColors\.(?:defaultAccent|primary)\b'),
      RegExp(
        r'Color\(0x[Ff][Ff](?:1[Dd][Bb]954|3[Dd][Dd][Cc]97|56[Aa]8[Ff][Ff]|'
        r'[Ff][Ff][Cc]857|[Ff][Ff]6[Bb]6[Bb]|[Bb]388[Ff][Ff])\)',
      ),
      RegExp(r'Colors\.(?:green|greenAccent)\b'),
    ];
    final offenders = <String>[];

    for (final entity in Directory(
      'lib/presentation',
    ).listSync(recursive: true)..sort((a, b) => a.path.compareTo(b.path))) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('appearance_screen.dart')) continue;
      final source = entity.readAsStringSync();
      for (final pattern in forbiddenPatterns) {
        if (pattern.hasMatch(source)) {
          offenders.add('${entity.path}: ${pattern.pattern}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'UI accent colors must come from Theme.of(context).colorScheme.primary '
          'or context.appAccent.\n${offenders.join('\n')}',
    );
  });
}
