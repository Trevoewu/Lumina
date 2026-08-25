import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum AppLogLevel { debug, warning, error }

/// The four buckets the log console groups entries into. Only the first three
/// get a filter chip; `sys` shows under "All".
enum AppLogCategory {
  asr('ASR'),
  ai('AI'),
  tts('TTS'),
  sys('SYS');

  final String label;

  const AppLogCategory(this.label);
}

class AppLogEntry {
  final DateTime timestamp;
  final AppLogLevel level;
  final String source;
  final String message;
  final String? error;
  final String? stackTrace;

  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.error,
    this.stackTrace,
  });

  factory AppLogEntry.fromJson(Map<String, dynamic> json) {
    return AppLogEntry(
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      level: _parseLevel(json['level'] as String?),
      source: json['source'] as String? ?? 'App',
      message: json['message'] as String? ?? '',
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'source': source,
    'message': message,
    if (error != null) 'error': error,
    if (stackTrace != null) 'stackTrace': stackTrace,
  };

  /// Subsystem bucket the settings log console filters by. Derived from
  /// [source] so call sites keep their finer-grained tags.
  AppLogCategory get category => switch (source) {
    'Podcast' => AppLogCategory.asr,
    'Generation' || 'Voice' => AppLogCategory.tts,
    'AI' || 'Dictionary' => AppLogCategory.ai,
    _ => AppLogCategory.sys,
  };

  String get formatted {
    final buffer = StringBuffer(
      '[${timestamp.toLocal().toIso8601String()}] '
      '[${level.name.toUpperCase()}] [$source] $message',
    );
    if (error != null && error!.isNotEmpty) buffer.write('\n$error');
    if (stackTrace != null && stackTrace!.isNotEmpty) {
      buffer.write('\n$stackTrace');
    }
    return buffer.toString();
  }

  static AppLogLevel _parseLevel(String? value) {
    if (value == 'info') return AppLogLevel.debug;
    return AppLogLevel.values.firstWhere(
      (level) => level.name == value,
      orElse: () => AppLogLevel.debug,
    );
  }
}

class AppLogService {
  static const _maximumEntries = 500;
  static const _maximumFileBytes = 2 * 1024 * 1024;
  static final AppLogService instance = AppLogService._();

  final ValueNotifier<List<AppLogEntry>> entries = ValueNotifier(const []);
  File? _file;
  Future<void> _writeQueue = Future.value();

  AppLogService._();

  Future<void> initialize() async {
    try {
      final supportDirectory = await getApplicationSupportDirectory();
      final directory = Directory(p.join(supportDirectory.path, 'logs'));
      await directory.create(recursive: true);
      _file = File(p.join(directory.path, 'lumina.jsonl'));
      if (await _file!.exists()) {
        final lines = await _file!.readAsLines();
        final loaded = <AppLogEntry>[];
        final firstLine = lines.length > _maximumEntries
            ? lines.length - _maximumEntries
            : 0;
        for (final line in lines.skip(firstLine)) {
          try {
            loaded.add(
              AppLogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>),
            );
          } catch (_) {
            // Ignore incomplete lines left by an interrupted write.
          }
        }
        entries.value = List.unmodifiable(loaded);
        if (await _file!.length() > _maximumFileBytes) {
          await _rewriteFile(loaded);
        }
      }
    } catch (error, stackTrace) {
      _add(
        AppLogEntry(
          timestamp: DateTime.now(),
          level: AppLogLevel.warning,
          source: 'Logger',
          message: '日志文件初始化失败，将仅保留本次运行日志',
          error: error.toString(),
          stackTrace: stackTrace.toString(),
        ),
        persist: false,
      );
    }
    _record(AppLogLevel.debug, 'App', 'Lumina 启动');
  }

  String exportText() =>
      entries.value.map((entry) => entry.formatted).join('\n\n');

  Future<void> clear() {
    entries.value = const [];
    _writeQueue = _writeQueue.then((_) async {
      final file = _file;
      if (file == null) return;
      try {
        await file.writeAsString('', flush: true);
      } catch (_) {
        // The in-memory log is still cleared if the file is unavailable.
      }
    });
    return _writeQueue;
  }

  void _record(
    AppLogLevel level,
    String source,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: level,
        source: source,
        message: message,
        error: error?.toString(),
        stackTrace: stackTrace?.toString(),
      ),
    );
  }

  void _add(AppLogEntry entry, {bool persist = true}) {
    final updated = [...entries.value, entry];
    if (updated.length > _maximumEntries) {
      updated.removeRange(0, updated.length - _maximumEntries);
    }
    entries.value = List.unmodifiable(updated);
    if (!persist) return;

    final encoded = '${jsonEncode(entry.toJson())}\n';
    _writeQueue = _writeQueue.then((_) async {
      final file = _file;
      if (file == null) return;
      try {
        await file.writeAsString(encoded, mode: FileMode.append, flush: true);
      } catch (_) {
        // Logging must never interrupt playback or generation.
      }
    });
    unawaited(_writeQueue);
  }

  Future<void> _rewriteFile(List<AppLogEntry> currentEntries) async {
    final file = _file;
    if (file == null) return;
    final content = currentEntries
        .map((entry) => jsonEncode(entry.toJson()))
        .join('\n');
    await file.writeAsString(content.isEmpty ? '' : '$content\n', flush: true);
  }
}

abstract final class AppLogger {
  static void info(String source, String message) {
    AppLogService.instance._record(AppLogLevel.debug, source, message);
  }

  static void warning(
    String source,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    AppLogService.instance._record(
      AppLogLevel.warning,
      source,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String source,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    AppLogService.instance._record(
      AppLogLevel.error,
      source,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
