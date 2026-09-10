import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/reader/widgets/epub_reader_view.dart';
import 'package:lumina/presentation/screens/reader/widgets/reader_appearance_sheet.dart';
import 'package:lumina/presentation/widgets/design_system/app_icon.dart';

// Run on a simulator/device: flutter test integration_test/epub_typography_test.dart -d <id>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'EPUB typography overrides fixed publisher sizes without compounding',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final directory = await Directory.systemTemp.createTemp(
        'epub_typography_',
      );
      final file = File('${directory.path}/typography.epub');
      await file.writeAsBytes(_fixture());
      final controller = EpubController();
      var loaded = false;
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  actions: [
                    IconButton(
                      tooltip: 'Typography',
                      onPressed: () => showReaderAppearanceSheet(context),
                      icon: const Icon(Icons.text_fields),
                    ),
                  ],
                ),
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 126),
                    child: EpubReaderView(
                      file: file,
                      controller: controller,
                      onEpubLoaded: () => loaded = true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 300 && !loaded; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(loaded, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      final baseline = await _metrics(controller);
      expect(baseline['fixed'], closeTo(12, .1));
      expect(baseline['relative'], closeTo(16, .1));

      await tester.tap(find.byTooltip('Typography'));
      await tester.pumpAndSettle();
      final plus = find.byWidgetPredicate(
        (w) => w is AppIcon && w.icon == AppIcons.addCircle,
      );
      final minus = find.byWidgetPredicate(
        (w) => w is AppIcon && w.icon == AppIcons.minusSignCircle,
      );
      for (var i = 0; i < 6; i++) {
        await tester.tap(plus);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(find.text('130%'), findsOneWidget);
      final larger = await _metrics(controller);
      for (final name in ['fixed', 'relative', 'nested', 'heading']) {
        expect(
          larger[name],
          closeTo((baseline[name] as num) * 1.3, .15),
          reason: name,
        );
      }
      expect(larger['pages'] as num, greaterThan(baseline['pages'] as num));

      // Return through several updates; nested em sizes must not multiply again.
      for (var i = 0; i < 9; i++) {
        await tester.tap(minus);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      final smaller = await _metrics(controller);
      for (final name in ['fixed', 'relative', 'nested', 'heading']) {
        expect(
          smaller[name],
          closeTo((baseline[name] as num) * .85, .15),
          reason: name,
        );
      }
      await tester.tap(find.text('Menlo'));
      await tester.pumpAndSettle();
      expect((await _metrics(controller))['family'], contains('Menlo'));
      await tester.tap(find.text('System').last);
      await tester.pumpAndSettle();
      expect((await _metrics(controller))['family'], contains('Georgia'));

      Navigator.of(tester.element(find.text('Typography & Theme'))).pop();
      await tester.pumpAndSettle();
      controller.display(cfi: 'two.xhtml');
      await tester.pump(const Duration(seconds: 1));
      final nextChapter = await _metrics(controller);
      expect(nextChapter['chapter'], 1);
      expect(nextChapter['fixed'], closeTo(12 * .85, .15));
      expect(
        nextChapter['heading'],
        closeTo((baseline['heading'] as num) * .85, .15),
      );
      if (Platform.isMacOS) {
        Future<num> page() async =>
            (await controller.webViewController!.callMethod('eval', [
                  'rendition.location.start.displayed.page',
                ]))
                as num;
        final rect = tester.getRect(find.byType(EpubReaderView));
        final point = Offset(rect.left + rect.width * .9, rect.center.dy);
        final initialPage = await page();
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 600));
        expect(await page(), initialPage + 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump(const Duration(milliseconds: 600));
        expect(await page(), initialPage);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 600));
        expect(await page(), initialPage + 1);
        tester.binding.handlePointerEvent(
          PointerScrollEvent(
            position: point,
            scrollDelta: const Offset(-60, 0),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(await page(), initialPage);
        tester.binding.handlePointerEvent(
          PointerScrollEvent(position: point, scrollDelta: const Offset(60, 0)),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(await page(), initialPage + 1);
      }
      debugPrint(
        'EPUB typography verified: baseline=$baseline larger=$larger smaller=$smaller next=$nextChapter',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

Future<Map<String, dynamic>> _metrics(EpubController controller) async {
  final result = await controller.webViewController!.callMethod('eval', [
    r'''
    JSON.stringify((function() {
      var c = rendition.getContents().find(function(c) { return c.sectionIndex === rendition.location.start.index; }), d = c.document;
      function size(id) { return parseFloat(c.window.getComputedStyle(d.getElementById(id)).fontSize); }
      return {chapter:c.sectionIndex, fixed:size('fixed'), relative:size('relative'), nested:size('nested'), heading:size('heading'),
        family:c.window.getComputedStyle(d.getElementById('fixed')).fontFamily,
        pages:rendition.location.start.displayed.total};
    })())
  ''',
  ]);
  return jsonDecode(result as String) as Map<String, dynamic>;
}

List<int> _fixture() {
  final archive = Archive();
  void add(String name, String content) =>
      archive.addFile(ArchiveFile.string(name, content));
  add('mimetype', 'application/epub+zip');
  add(
    'META-INF/container.xml',
    '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="book.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
  );
  add(
    'book.opf',
    '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">typography-test</dc:identifier><dc:title>Typography Test</dc:title><dc:language>en</dc:language></metadata><manifest><item id="one" href="one.xhtml" media-type="application/xhtml+xml"/><item id="two" href="two.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="one"/><itemref idref="two"/></spine></package>',
  );
  for (final name in ['one', 'two']) {
    add(
      '$name.xhtml',
      '''<html xmlns="http://www.w3.org/1999/xhtml"><head><title>$name</title>
      <style>p {font-size:12px !important;} #relative {font-size:1em !important;}</style></head><body>
      <h1 id="heading" style="font-size:28px !important">Chapter $name</h1>
      <p id="fixed" style="font-size:9pt !important;font-family:Georgia !important">Fixed publisher size.</p>
      <p id="relative">Relative text <span id="nested" style="font-size:.75em">nested span</span>.</p>
      ${List.generate(120, (i) => '<p>Paragraph $i. The path followed the river past the old village. A quiet breeze moved through the trees and we continued reading beneath the afternoon sky.</p>').join()}
      </body></html>''',
    );
  }
  return ZipEncoder().encode(archive);
}
