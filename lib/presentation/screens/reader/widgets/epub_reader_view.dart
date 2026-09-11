import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

import '../../../../core/appearance.dart';
import 'epub_reader_script.dart';
import '../../../../core/app_colors.dart';
import '../../../../core/app_localizations.dart';

/// 全功能 EPUB 渲染视图：
/// 直接基于 WebView + epub.js，保真呈现书籍原始 CSS 样式、插图、多级排版与内嵌字体。
class EpubReaderView extends ConsumerStatefulWidget {
  final File file;
  final EpubController controller;
  final String? initialCfi;
  final ValueChanged<List<EpubChapter>>? onChaptersLoaded;
  final ValueChanged<EpubLocation>? onRelocated;
  final VoidCallback? onEpubLoaded;
  final VoidCallback? onTapCenter;
  final ValueChanged<String>? onLookupWord;
  final bool isScrolledFlow;
  final void Function(int currentPage, int totalPages, double progress)?
  onPageChanged;

  const EpubReaderView({
    super.key,
    required this.file,
    required this.controller,
    this.initialCfi,
    this.onChaptersLoaded,
    this.onRelocated,
    this.onEpubLoaded,
    this.onTapCenter,
    this.onLookupWord,
    this.isScrolledFlow = false,
    this.onPageChanged,
  });

  @override
  ConsumerState<EpubReaderView> createState() => _EpubReaderViewState();
}

class _EpubReaderViewState extends ConsumerState<EpubReaderView> {
  final FocusNode _focusNode = FocusNode();
  bool _loading = true;
  Uint8List? _epubBytes;
  String? _selectedText;
  int? _pointer;
  Offset? _pointerStart;
  Duration? _pointerTime;
  bool _multiplePointers = false;

  bool get _usesNativeGestures =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  void _pointerDown(PointerDownEvent event) {
    if (_loading || event.buttons != kPrimaryButton) {
      return;
    }
    _focusNode.requestFocus();
    if (_pointer != null) {
      _multiplePointers = true;
      return;
    }
    _pointer = event.pointer;
    _pointerStart = event.localPosition;
    _pointerTime = event.timeStamp;
    _multiplePointers = false;
    if (!_usesNativeGestures) return;
    widget.controller.webViewController?.callMethod('luminaPointerDown', [
      event.localPosition.dx -
          ref.read(appearanceControllerProvider).readerMargin,
      event.localPosition.dy,
    ]);
  }

  void _pointerUp(PointerUpEvent event) {
    if (_pointer != event.pointer) return;
    final start = _pointerStart;
    final time = _pointerTime;
    _pointer = null;
    if (_multiplePointers || start == null || time == null) return;
    final delta = event.localPosition - start;
    final margin = ref.read(appearanceControllerProvider).readerMargin;
    if (!_usesNativeGestures) {
      final width = context.size!.width;
      if (delta.distance < 15 &&
          (event.timeStamp - time).inMilliseconds < 350) {
        if (start.dx < margin) widget.controller.prev();
        if (start.dx > width - margin) widget.controller.next();
      }
      return;
    }
    widget.controller.webViewController?.callMethod('luminaPointerUp', [
      event.localPosition.dx - margin,
      event.localPosition.dy,
      delta.dx,
      delta.dy,
      (event.timeStamp - time).inMilliseconds,
    ]);
  }

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  @override
  void didUpdateWidget(covariant EpubReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isScrolledFlow != widget.isScrolledFlow) {
      widget.controller.setFlow(
        flow: widget.isScrolledFlow ? EpubFlow.scrolled : EpubFlow.paginated,
      );
      _applyReaderEnhancements(ref.read(appearanceControllerProvider));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme changes rebuild Flutter, but EpubViewer does not forward updated
    // display settings to the existing WebView.
    if (!_loading && widget.controller.webViewController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final appearance = ref.read(appearanceControllerProvider);
        widget.controller.updateTheme(theme: _buildEpubTheme(context));
        _applyReaderEnhancements(appearance);
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBytes() async {
    try {
      final bytes = await widget.file.readAsBytes();
      if (mounted) {
        setState(() => _epubBytes = bytes);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyReaderEnhancements(AppearanceSettings appearance) {
    final textColor = context.appTextPrimary;
    final textHex = '#${textColor.toHexRgb()}';
    final bgHex = '#${context.appBackground.toHexRgb()}';

    final js = buildEpubReaderScript(
      background: bgHex,
      foreground: textHex,
      scrolled: widget.isScrolledFlow,
      nativeGestures: _usesNativeGestures,
      fontScale: appearance.fontScale,
      lineHeight: appearance.readerLineHeight,
      indent: appearance.readerIndent,
      fontFamily: appearance.fontOption.fontFamily,
    );
    widget.controller.webViewController
        ?.callMethod('eval', [js])
        .catchError(
          (Object error) => debugPrint('EPUB layout injection failed: $error'),
        );
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceControllerProvider);
    // 监听外观变化并同步到 EpubController
    ref.listen(appearanceControllerProvider, (prev, next) {
      if (prev?.fontScale != next.fontScale ||
          prev?.fontId != next.fontId ||
          prev?.readerLineHeight != next.readerLineHeight ||
          prev?.readerIndent != next.readerIndent ||
          prev?.lightPalette != next.lightPalette ||
          prev?.darkPalette != next.darkPalette) {
        try {
          widget.controller.updateTheme(theme: _buildEpubTheme(context));
          _applyReaderEnhancements(next);
        } catch (_) {}
      }
    });

    final currentTheme = _buildEpubTheme(context);

    if (_epubBytes == null) {
      return ColoredBox(
        color: context.appBackground,
        child: Center(
          child: CircularProgressIndicator(
            color: context.appAccent,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    return _nativeInput(
      Padding(
        padding: EdgeInsets.symmetric(horizontal: appearance.readerMargin),
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                  event.logicalKey == LogicalKeyboardKey.pageDown ||
                  event.logicalKey == LogicalKeyboardKey.space) {
                try {
                  widget.controller.next();
                } catch (_) {}
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                  event.logicalKey == LogicalKeyboardKey.pageUp) {
                try {
                  widget.controller.prev();
                } catch (_) {}
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            children: [
              EpubViewer(
                epubController: widget.controller,
                epubSource: EpubSource.fromData(_epubBytes!),
                initialCfi: widget.initialCfi,
                displaySettings: EpubDisplaySettings(
                  // The enhancement script scales publisher sizes from this stable
                  // baseline, including fixed-size paragraphs and nested spans.
                  fontSize: 16,
                  flow: widget.isScrolledFlow
                      ? EpubFlow.scrolled
                      : EpubFlow.paginated,
                  snap: false,
                  useSnapAnimationAndroid: false,
                  spread: EpubSpread.none,
                  manager: EpubManager.continuous,
                  theme: currentTheme,
                  allowScriptedContent: false,
                ),
                selectionContextMenu: EpubContextMenu(
                  hideDefaultSystemItems: false,
                  items: [
                    EpubContextMenuItem(
                      id: 1,
                      title: context.tr('查词', 'Lookup', '調べる'),
                      action: () {
                        final text = _selectedText?.trim();
                        if (text != null && text.isNotEmpty) {
                          widget.onLookupWord?.call(text);
                        }
                      },
                    ),
                  ],
                ),
                onEpubLoaded: () {
                  if (mounted) {
                    setState(() => _loading = false);
                  }
                  _applyReaderEnhancements(appearance);
                  widget.onEpubLoaded?.call();
                },
                onChaptersLoaded: (chapters) {
                  if (mounted && _loading) {
                    setState(() => _loading = false);
                  }
                  _applyReaderEnhancements(appearance);
                  widget.onChaptersLoaded?.call(chapters);
                },
                onRelocated: (location) {
                  _applyReaderEnhancements(appearance);
                  final progress = location.progress;
                  final cur = (progress * 100).round();
                  widget.onPageChanged?.call(cur, 100, progress);
                  widget.onRelocated?.call(location);
                },
                onSelection: (selectedText, cfiRange, selectionRect, viewRect) {
                  _selectedText = selectedText;
                },
                onDeselection: () {
                  _selectedText = null;
                },
                // The injected handler owns tap/swipe classification. The package
                // reports touch-up even for drags and text-selection gestures.
                onTouchUp: (x, y) => widget.onTapCenter?.call(),
              ),

              if (_loading)
                Positioned.fill(
                  child: ColoredBox(
                    color: context.appBackground,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: context.appAccent,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nativeInput(Widget child) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _pointerDown,
      onPointerUp: _pointerUp,
      onPointerPanZoomStart: (_) {
        if (_usesNativeGestures && !_loading) {
          widget.controller.webViewController?.callMethod('eval', [
            'window._luminaWheel = null',
          ]);
        }
      },
      onPointerPanZoomUpdate: (event) {
        if (!_usesNativeGestures ||
            _loading ||
            widget.isScrolledFlow ||
            event.scale != 1 ||
            event.panDelta.dx.abs() <= event.panDelta.dy.abs()) {
          return;
        }
        widget.controller.webViewController?.callMethod('luminaWheel', [
          -event.panDelta.dx,
        ]);
      },
      onPointerSignal: (event) {
        if (!_usesNativeGestures ||
            _loading ||
            widget.isScrolledFlow ||
            event is! PointerScrollEvent ||
            event.scrollDelta.dx.abs() <= event.scrollDelta.dy.abs()) {
          return;
        }
        GestureBinding.instance.pointerSignalResolver.register(event, (_) {
          widget.controller.webViewController?.callMethod('luminaWheel', [
            event.scrollDelta.dx,
          ]);
        });
      },
      onPointerCancel: (event) {
        if (_pointer == event.pointer) _pointer = null;
      },
      child: child,
    );
  }

  EpubTheme _buildEpubTheme(BuildContext context) {
    final backgroundColor = context.appBackground;
    final textColor = context.appTextPrimary;
    final textHex = '#${textColor.toHexRgb()}';

    return EpubTheme.custom(
      backgroundDecoration: BoxDecoration(color: backgroundColor),
      foregroundColor: textColor,
      customCss: {
        'body': {'color': textHex},
      },
    );
  }
}
