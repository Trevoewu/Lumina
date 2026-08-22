import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_handler/share_handler.dart';

import '../core/database_provider.dart';
import 'app_log_service.dart';
import 'book_import_service.dart';

enum IncomingBookImportPhase { idle, importing, succeeded, failed }

class IncomingBookImportState {
  final IncomingBookImportPhase phase;
  final int eventId;
  final String? fileName;
  final BookImportResult? result;
  final Object? error;

  const IncomingBookImportState({
    this.phase = IncomingBookImportPhase.idle,
    this.eventId = 0,
    this.fileName,
    this.result,
    this.error,
  });
}

/// Receives files opened from iOS's share sheet and imports EPUB attachments.
class IncomingBookImportController extends Notifier<IncomingBookImportState> {
  StreamSubscription<SharedMedia>? _subscription;
  Future<void> _pendingImports = Future.value();
  bool _disposed = false;

  @override
  IncomingBookImportState build() {
    ref.onDispose(() {
      _disposed = true;
      _subscription?.cancel();
    });
    if (Platform.isIOS) Future<void>.microtask(_initialize);
    return const IncomingBookImportState();
  }

  Future<void> _initialize() async {
    final handler = ShareHandlerPlatform.instance;
    try {
      _subscription = handler.sharedMediaStream.listen(
        _enqueueMedia,
        onError: (Object error, StackTrace stackTrace) {
          AppLogger.error(
            'IncomingBook',
            '接收外部 EPUB 失败',
            error: error,
            stackTrace: stackTrace,
          );
        },
      );
      final initialMedia = await handler.getInitialSharedMedia();
      if (initialMedia != null) {
        _enqueueMedia(initialMedia);
        if (epubPaths(initialMedia).isEmpty) {
          await handler.resetInitialSharedMedia();
        }
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'IncomingBook',
        '初始化外部文件接收失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _enqueueMedia(SharedMedia media) {
    final paths = epubPaths(media);
    if (paths.isEmpty) return;
    _pendingImports = _pendingImports
        .then((_) async {
          for (final path in paths) {
            await _import(path);
          }
          await ShareHandlerPlatform.instance.resetInitialSharedMedia();
        })
        .catchError((Object error, StackTrace stackTrace) {
          AppLogger.error(
            'IncomingBook',
            '处理外部 EPUB 队列失败',
            error: error,
            stackTrace: stackTrace,
          );
        });
  }

  static List<String> epubPaths(SharedMedia media) {
    return (media.attachments ?? const <SharedAttachment?>[])
        .whereType<SharedAttachment>()
        .map((attachment) => attachment.path)
        .where((path) => p.extension(path).toLowerCase() == '.epub')
        .toSet()
        .toList(growable: false);
  }

  Future<void> _import(String path) async {
    final eventId = state.eventId + 1;
    final fileName = p.basename(path);
    if (!_disposed) {
      state = IncomingBookImportState(
        phase: IncomingBookImportPhase.importing,
        eventId: eventId,
        fileName: fileName,
      );
    }

    try {
      if (!await File(path).exists()) {
        throw FileSystemException('EPUB 文件不可访问', path);
      }
      final result = await BookImportService(
        ref.read(appDatabaseProvider),
      ).importFile(path);
      if (_disposed) return;
      state = IncomingBookImportState(
        phase: IncomingBookImportPhase.succeeded,
        eventId: eventId,
        fileName: fileName,
        result: result,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'IncomingBook',
        '自动导入 EPUB 失败 path=$path',
        error: error,
        stackTrace: stackTrace,
      );
      if (_disposed) return;
      state = IncomingBookImportState(
        phase: IncomingBookImportPhase.failed,
        eventId: eventId,
        fileName: fileName,
        error: error,
      );
    }
  }
}
