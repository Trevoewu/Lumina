import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart' as cache;

abstract interface class ImageDiskCache {
  File? peek(String url);

  Future<File> load(String url);

  Future<void> clear();
}

class AppImageDiskCache implements ImageDiskCache {
  final cache.BaseCacheManager _manager;
  final Map<String, File> _memoryFiles = {};
  final Map<String, Future<File>> _inFlight = {};
  final Set<String> _refreshing = {};

  AppImageDiskCache({cache.BaseCacheManager? manager})
    : _manager =
          manager ??
          cache.CacheManager(
            cache.Config(
              'lumina_image_cache_v1',
              stalePeriod: const Duration(days: 30),
              maxNrOfCacheObjects: 500,
            ),
          );

  @override
  File? peek(String url) => _memoryFiles[url];

  @override
  Future<File> load(String url) {
    final memoryFile = _memoryFiles[url];
    if (memoryFile != null) return Future.value(memoryFile);
    final running = _inFlight[url];
    if (running != null) return running;

    late final Future<File> future;
    future = _resolve(url).whenComplete(() {
      if (identical(_inFlight[url], future)) _inFlight.remove(url);
    });
    _inFlight[url] = future;
    return future;
  }

  Future<File> _resolve(String url) async {
    final cached = await _manager.getFileFromCache(url);
    if (cached != null && await cached.file.exists()) {
      final file = File(cached.file.path);
      _memoryFiles[url] = file;
      if (cached.validTill.isBefore(DateTime.now())) _refresh(url);
      return file;
    }

    final downloaded = await _manager.getSingleFile(url, key: url);
    final file = File(downloaded.path);
    _memoryFiles[url] = file;
    return file;
  }

  void _refresh(String url) {
    if (!_refreshing.add(url)) return;
    unawaited(_refreshFile(url));
  }

  Future<void> _refreshFile(String url) async {
    try {
      final info = await _manager.downloadFile(url, key: url);
      _memoryFiles[url] = File(info.file.path);
    } catch (_) {
      // Keep serving the stale file when a background refresh is unavailable.
    } finally {
      _refreshing.remove(url);
    }
  }

  @override
  Future<void> clear() async {
    _memoryFiles.clear();
    _inFlight.clear();
    _refreshing.clear();
    await _manager.emptyCache();
  }
}

ImageDiskCache? _appImageDiskCache;

ImageDiskCache get appImageDiskCache =>
    _appImageDiskCache ??= AppImageDiskCache();
