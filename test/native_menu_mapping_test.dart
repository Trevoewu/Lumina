import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/presentation/widgets/app_glass_controls.dart';

void main() {
  final entries = <PopupMenuEntry<String>>[
    const PopupMenuItem(value: 'pause', child: Text('Pause transcription')),
    const PopupMenuDivider(),
    const PopupMenuItem(value: 'show', child: Text('Go to show')),
    const PopupMenuItem(
      value: 'busy',
      enabled: false,
      child: Text('Pausing…'),
    ),
  ];

  test('menu entries become native items one for one', () {
    final native = nativeMenuItems(entries);

    expect(native, hasLength(entries.length));
    expect((native[0] as CNPopupMenuItem).label, 'Pause transcription');
    expect(native[1], isA<CNPopupMenuDivider>());
    expect((native[2] as CNPopupMenuItem).label, 'Go to show');
    expect((native[3] as CNPopupMenuItem).enabled, isFalse);
  });

  test('a native selection maps back to its value', () {
    // The index counts the divider, as the native menu reports it.
    expect(nativeMenuValue(entries, 0), 'pause');
    expect(nativeMenuValue(entries, 2), 'show');
    expect(nativeMenuValue(entries, 1), isNull);
    expect(nativeMenuValue(entries, 3), isNull);
    expect(nativeMenuValue(entries, 9), isNull);
  });
}
