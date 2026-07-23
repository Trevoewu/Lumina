import 'package:dio/dio.dart';

class PodcastIndexPodcast {
  final String id;
  final String title;
  final String? author;
  final String feedUrl;
  final String? imageUrl;
  final List<String> genres;
  final int episodeCount;

  const PodcastIndexPodcast({
    required this.id,
    required this.title,
    required this.author,
    required this.feedUrl,
    required this.imageUrl,
    required this.genres,
    required this.episodeCount,
  });
}

/// Lightweight Podcast Index directory search.
///
/// Podcast Index's Apple-compatible `/search` endpoint is explicitly public
/// and does not require developer credentials. Search results remain in
/// memory; selecting one subscribes through the publisher's original RSS.
class PodcastIndexRepository {
  final Dio _dio;

  PodcastIndexRepository({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.podcastindex.org',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {
                'user-agent': 'Lumina/1.0 (+local podcast reader)',
                'accept': 'application/json',
              },
            ),
          );

  Future<List<PodcastIndexPodcast>> search(String query) async {
    final term = query.trim();
    if (term.isEmpty) {
      throw const FormatException('请输入 Podcast 搜索词。');
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/search',
      // The public Podcast Index Apple-replacement endpoint documents `term`
      // (plus optional `pretty`) and already scopes results to podcasts.
      queryParameters: {'term': term},
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Podcast Index 没有返回搜索内容。');
    }
    return parsePodcastIndexSearchResponse(data);
  }
}

List<PodcastIndexPodcast> parsePodcastIndexSearchResponse(
  Map<String, dynamic> data,
) {
  final rawResults = data['results'];
  if (rawResults is! List) {
    throw const FormatException('Podcast Index 搜索结果格式无效。');
  }

  final seenFeeds = <String>{};
  final results = <PodcastIndexPodcast>[];
  for (final raw in rawResults) {
    if (raw is! Map) continue;
    final item = Map<String, dynamic>.from(raw);
    final feedUrl = _stringValue(item['feedUrl']);
    final title =
        _stringValue(item['collectionName']) ?? _stringValue(item['trackName']);
    if (feedUrl == null || title == null) continue;
    final feedUri = Uri.tryParse(feedUrl);
    if (feedUri == null ||
        !feedUri.hasAuthority ||
        (feedUri.scheme != 'https' && feedUri.scheme != 'http')) {
      continue;
    }
    final deduplicationKey = feedUri.toString();
    if (!seenFeeds.add(deduplicationKey)) continue;

    final rawGenres = item['genres'];
    final genres = rawGenres is List
        ? rawGenres
              .map(_stringValue)
              .whereType<String>()
              .toList(growable: false)
        : const <String>[];
    final identifier =
        item['collectionId'] ?? item['trackId'] ?? deduplicationKey;
    results.add(
      PodcastIndexPodcast(
        id: identifier.toString(),
        title: title,
        author: _stringValue(item['artistName']),
        feedUrl: deduplicationKey,
        imageUrl:
            _stringValue(item['artworkUrl600']) ??
            _stringValue(item['artworkUrl100']) ??
            _stringValue(item['artworkUrl60']) ??
            _stringValue(item['artworkUrl30']),
        genres: genres,
        episodeCount: _intValue(item['trackCount']),
      ),
    );
    if (results.length == 40) break;
  }
  return results;
}

String? _stringValue(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
