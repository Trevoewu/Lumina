import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/main.dart';

void main() {
  testWidgets('Lumina app starts on library screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LuminaApp()));
    await tester.pump(const Duration(milliseconds: 300));

    // 书架页应该显示标题或导入提示
    expect(find.text('Your Library'), findsOneWidget);
  });
}
