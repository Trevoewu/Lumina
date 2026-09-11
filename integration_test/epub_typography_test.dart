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
import 'package:lumina/core/appearance.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/reader/widgets/epub_reader_view.dart';
import 'package:lumina/presentation/screens/reader/widgets/reader_bottom_bar.dart';

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
      var barsVisible = true;
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: SafeArea(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: EpubReaderView(
                            file: file,
                            controller: controller,
                            onEpubLoaded: () => loaded = true,
                            onTapCenter: () =>
                                setState(() => barsVisible = !barsVisible),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !barsVisible,
                          child: ReaderBottomBar(
                            isVisible: barsVisible,
                            isEpub: true,
                            progress: 0,
                            currentPage: 1,
                            totalPages: 10,
                            chapterTitle: 'Chapter one',
                            hasPrevChapter: false,
                            hasNextChapter: true,
                            onToggleToc: () {},
                            onSeekProgress: (_) {},
                            onToggleTheme: () {},
                            onOpenAi: () {},
                            onOpenTranslate: () {},
                            onStartListening: () {},
                          ),
                        ),
                      ),
                    ],
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
      expect(
        baseline['bodyHeight'],
        closeTo(baseline['viewportHeight'] as num, 1),
      );
      expect(baseline['paddingTop'], greaterThan(0));
      final stableRect = tester.getRect(find.byType(EpubReaderView));
      await tester.tapAt(stableRect.center);
      await tester.pump(const Duration(milliseconds: 600));
      expect(barsVisible, isFalse);
      expect(tester.getRect(find.byType(EpubReaderView)), stableRect);
      await tester.tapAt(stableRect.center);
      await tester.pump(const Duration(milliseconds: 600));
      expect(barsVisible, isTrue);
      expect(tester.getRect(find.byType(EpubReaderView)), stableRect);

      await tester.tap(find.byTooltip('Typography'));
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('READER_CAPTURE')) {
        debugPrint('READER_PANEL_READY');
        await tester.pump(const Duration(seconds: 5));
      }
      final fontSlider = find.byKey(const Key('reader-font-slider'));
      await tester.drag(
        fontSlider,
        Offset(tester.getSize(fontSlider).width, 0),
      );
      await tester.pumpAndSettle();
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
      await tester.drag(
        fontSlider,
        Offset(-tester.getSize(fontSlider).width, 0),
      );
      await tester.pumpAndSettle();
      final smaller = await _metrics(controller);
      for (final name in ['fixed', 'relative', 'nested', 'heading']) {
        expect(
          smaller[name],
          closeTo((baseline[name] as num) * .85, .15),
          reason: name,
        );
      }
      await tester.tap(find.byKey(const Key('reader-font-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('Menlo'),
          matching: find.byWidgetPredicate((w) => w is PopupMenuEntry),
        ),
      );
      await tester.pumpAndSettle();
      expect((await _metrics(controller))['family'], contains('Menlo'));
      await tester.tap(find.byKey(const Key('reader-font-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('System').last,
          matching: find.byWidgetPredicate((w) => w is PopupMenuEntry),
        ),
      );
      await tester.pumpAndSettle();
      expect((await _metrics(controller))['family'], contains('Georgia'));

      // The actual controls must change EPUB geometry, not just Flutter UI.
      final marginSlider = find.byKey(const Key('reader-margin-slider'));
      await tester.tapAt(
        tester.getRect(marginSlider).centerRight - const Offset(12, 0),
      );
      await tester.pumpAndSettle();
      final provider = ProviderScope.containerOf(
        tester.element(find.byType(EpubReaderView)),
      );
      final margin = provider.read(appearanceControllerProvider).readerMargin;
      expect(margin, greaterThan(12));
      expect(
        (await _metrics(controller))['hostWidth'],
        closeTo((baseline['hostWidth'] as num) - 2 * (margin - 12), 1),
      );
      final lineSlider = find.byKey(const Key('reader-line-slider'));
      await tester.tapAt(
        tester.getRect(lineSlider).centerRight - const Offset(12, 0),
      );
      await tester.pumpAndSettle();
      final lineHeight = provider
          .read(appearanceControllerProvider)
          .readerLineHeight;
      expect(lineHeight, greaterThan(1.5));
      final spaced = await _metrics(controller);
      expect(
        spaced['lineHeight'],
        closeTo((spaced['fixed'] as num) * lineHeight, .2),
      );
      await tester.tap(find.byKey(const Key('reader-indent-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('Two characters'),
          matching: find.byWidgetPredicate((w) => w is PopupMenuEntry),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (await _metrics(controller))['indent'],
        closeTo((spaced['fixed'] as num) * 2, .2),
      );
      await tester.tap(find.byKey(const Key('reader-indent-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('Publisher'),
          matching: find.byWidgetPredicate((w) => w is PopupMenuEntry),
        ),
      );
      await tester.pumpAndSettle();
      expect((await _metrics(controller))['indent'], closeTo(18, .2));

      await tester.tap(find.byTooltip('Typography'));
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
      final pageRect = tester.getRect(find.byType(EpubReaderView));
      Future<num> currentPage() async =>
          (await controller.webViewController!.callMethod('eval', [
                'rendition.location.start.displayed.page',
              ]))
              as num;
      final firstPage = await currentPage();
      await tester.tapAt(Offset(pageRect.right - 2, pageRect.center.dy));
      await tester.pump(const Duration(milliseconds: 600));
      expect(await currentPage(), firstPage + 1);
      await tester.tapAt(Offset(pageRect.left + 2, pageRect.center.dy));
      await tester.pump(const Duration(milliseconds: 600));
      expect(await currentPage(), firstPage);

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
        hostWidth:window.innerWidth,
        lineHeight:parseFloat(c.window.getComputedStyle(d.getElementById('fixed')).lineHeight),
        indent:parseFloat(c.window.getComputedStyle(d.getElementById('fixed')).textIndent),
        bodyHeight:parseFloat(c.window.getComputedStyle(d.body).height),
        viewportHeight:c.window.innerHeight,
        paddingTop:parseFloat(c.window.getComputedStyle(d.body).paddingTop),
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
      <style>p {font-size:12px !important;} #relative {font-size:1em !important;}</style></head><body class="chapter">
      <h1 id="heading" style="font-size:28px !important">Chapter $name</h1>
      <p id="fixed" style="font-size:9pt !important;font-family:Georgia !important;text-indent:18px !important">Fixed publisher size.</p>
      <p id="relative">Relative text <span id="nested" style="font-size:.75em">nested span</span>.</p>
      ${List.generate(120, (i) => '<p>Paragraph $i. The path followed the river past the old village. A quiet breeze moved through the trees and we continued reading beneath the afternoon sky.</p>').join()}
      </body></html>''',
    );
  }
  return ZipEncoder().encode(archive);
}
