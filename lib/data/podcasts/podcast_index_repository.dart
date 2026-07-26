import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

class PodcastIndexPodcast {
  final String id;
  final String title;
  final String? author;
  final String feedUrl;
  final String? imageUrl;
  final List<String> genres;
  final int episodeCount;
  final String? language;
  final int newestEpisodeAt;

  const PodcastIndexPodcast({
    required this.id,
    required this.title,
    required this.author,
    required this.feedUrl,
    required this.imageUrl,
    required this.genres,
    required this.episodeCount,
    this.language,
    this.newestEpisodeAt = 0,
  });
}

class PodcastDiscoverySeed {
  final String title;
  final String? author;
  final String feedUrl;
  final String? language;
  final double engagement;

  const PodcastDiscoverySeed({
    required this.title,
    required this.feedUrl,
    this.author,
    this.language,
    this.engagement = 0,
  });
}

enum PodcastRecommendationReason {
  becauseYouListen,
  category,
  trending,
  explore,
}

class PodcastIndexRecommendation {
  final PodcastIndexPodcast podcast;
  final PodcastRecommendationReason reason;
  final String? reasonContext;
  final double score;

  const PodcastIndexRecommendation({
    required this.podcast,
    required this.reason,
    required this.score,
    this.reasonContext,
  });
}

/// Lightweight Podcast Index directory search.
///
/// Podcast Index's Apple-compatible `/search` endpoint is explicitly public
/// and does not require developer credentials. Search results remain in
/// memory; selecting one subscribes through the publisher's original RSS.
class PodcastIndexRepository {
  final Dio _dio;
  final String _apiKey;
  final String _apiSecret;
  final int Function() _epochSeconds;

  PodcastIndexRepository({
    Dio? dio,
    String? apiKey,
    String? apiSecret,
    int Function()? epochSeconds,
  }) : _apiKey =
           apiKey ?? const String.fromEnvironment('PODCAST_INDEX_API_KEY'),
       _apiSecret =
           apiSecret ??
           const String.fromEnvironment('PODCAST_INDEX_API_SECRET'),
       _epochSeconds =
           epochSeconds ??
           (() => DateTime.now().millisecondsSinceEpoch ~/ 1000),
       _dio =
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

  bool get supportsTrending => _apiKey.isNotEmpty && _apiSecret.isNotEmpty;

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

  Future<List<PodcastIndexRecommendation>> discover({
    required List<PodcastDiscoverySeed> seeds,
    required Set<String> subscribedFeedUrls,
    String? preferredLanguage,
    int limit = 10,
  }) async {
    final normalizedLanguage = _normalizeLanguage(
      preferredLanguage ??
          seeds.map((seed) => seed.language).whereType<String>().firstOrNull,
    );
    final sortedSeeds = [...seeds]
      ..sort((left, right) => right.engagement.compareTo(left.engagement));
    final activeSeeds = sortedSeeds.take(2).toList(growable: false);
    final candidates = <String, _DiscoveryCandidate>{};
    final preferredGenres = <String, double>{};

    if (supportsTrending) {
      final trending = await _loadTrending(normalizedLanguage);
      for (var index = 0; index < trending.length; index++) {
        _addDiscoveryCandidate(
          candidates,
          trending[index],
          trendingScore: _rankScore(index, trending.length),
        );
      }
    }

    final seedBatches = await Future.wait([
      for (final seed in activeSeeds)
        _safeSearch(seed.title).then((items) => (seed: seed, items: items)),
    ]);
    for (final batch in seedBatches) {
      for (var index = 0; index < batch.items.length; index++) {
        final podcast = batch.items[index];
        if (_sameFeed(podcast.feedUrl, batch.seed.feedUrl)) {
          final weight = 1 + batch.seed.engagement.clamp(0.0, 1.0);
          for (final genre in podcast.genres) {
            final key = genre.toLowerCase();
            preferredGenres[key] = math.max(preferredGenres[key] ?? 0, weight);
          }
          continue;
        }
        _addDiscoveryCandidate(
          candidates,
          podcast,
          directoryScore: _rankScore(index, batch.items.length),
          personalSeed: batch.seed,
        );
      }
    }

    final categoryQueries = preferredGenres.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final explorationTerms = categoryQueries.isEmpty
        ? _fallbackDiscoveryTerms(normalizedLanguage)
        : categoryQueries
              .take(2)
              .map((entry) => entry.key)
              .toList(growable: false);
    final explorationBatches = await Future.wait([
      for (final term in explorationTerms)
        _safeSearch(term).then((items) => (term: term, items: items)),
    ]);
    for (final batch in explorationBatches) {
      for (var index = 0; index < batch.items.length; index++) {
        _addDiscoveryCandidate(
          candidates,
          batch.items[index],
          directoryScore: _rankScore(index, batch.items.length),
          explorationContext: batch.term,
        );
      }
    }

    final excluded = subscribedFeedUrls.map(_feedKey).toSet();
    final recommendations = <PodcastIndexRecommendation>[];
    for (final candidate in candidates.values) {
      final podcast = candidate.podcast;
      if (excluded.contains(_feedKey(podcast.feedUrl))) continue;
      final genres = podcast.genres.map((genre) => genre.toLowerCase()).toSet();
      final matchingGenre = preferredGenres.entries
          .where((entry) => genres.contains(entry.key))
          .fold<MapEntry<String, double>?>(
            null,
            (best, entry) =>
                best == null || entry.value > best.value ? entry : best,
          );
      final maximumGenreWeight = preferredGenres.values.fold<double>(
        0,
        math.max,
      );
      final categoryAffinity = matchingGenre == null || maximumGenreWeight <= 0
          ? 0.0
          : matchingGenre.value / maximumGenreWeight;
      final podcastLanguage = _normalizeLanguage(podcast.language);
      final languageMatch = normalizedLanguage == null
          ? 0.6
          : podcastLanguage == null
          ? 0.45
          : podcastLanguage == normalizedLanguage
          ? 1.0
          : 0.0;
      final freshness = _freshnessScore(podcast.newestEpisodeAt);
      final directorySignal = math.max(
        candidate.trendingScore,
        candidate.directoryScore,
      );
      final exploration = _stableExplorationScore(podcast.id);
      final score =
          categoryAffinity * 0.35 +
          languageMatch * 0.20 +
          directorySignal * 0.20 +
          freshness * 0.15 +
          exploration * 0.10 +
          (candidate.personalSeed == null ? 0 : 0.12);
      final reason = candidate.personalSeed != null
          ? PodcastRecommendationReason.becauseYouListen
          : matchingGenre != null
          ? PodcastRecommendationReason.category
          : candidate.trendingScore > 0
          ? PodcastRecommendationReason.trending
          : PodcastRecommendationReason.explore;
      recommendations.add(
        PodcastIndexRecommendation(
          podcast: podcast,
          reason: reason,
          reasonContext: switch (reason) {
            PodcastRecommendationReason.becauseYouListen =>
              candidate.personalSeed?.title,
            PodcastRecommendationReason.category =>
              podcast.genres
                  .where((genre) => genre.toLowerCase() == matchingGenre?.key)
                  .firstOrNull,
            PodcastRecommendationReason.trending => normalizedLanguage,
            PodcastRecommendationReason.explore => candidate.explorationContext,
          },
          score: score,
        ),
      );
    }
    recommendations.sort((left, right) => right.score.compareTo(left.score));
    return _diversifyRecommendations(recommendations, limit);
  }

  Future<List<PodcastIndexPodcast>> _loadTrending(String? language) async {
    if (!supportsTrending) return const [];
    final timestamp = _epochSeconds().toString();
    final authorization = sha1
        .convert(utf8.encode('$_apiKey$_apiSecret$timestamp'))
        .toString();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/1.0/podcasts/trending',
        queryParameters: {'max': 40, 'lang': ?language},
        options: Options(
          headers: {
            'X-Auth-Key': _apiKey,
            'X-Auth-Date': timestamp,
            'Authorization': authorization,
          },
        ),
      );
      final data = response.data;
      return data == null ? const [] : parsePodcastIndexTrendingResponse(data);
    } catch (_) {
      return const [];
    }
  }

  Future<List<PodcastIndexPodcast>> _safeSearch(String query) async {
    try {
      return await search(query);
    } catch (_) {
      return const [];
    }
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
        language:
            _stringValue(item['language']) ??
            _stringValue(item['country'])?.toLowerCase(),
        newestEpisodeAt: _timestampValue(item['releaseDate']),
      ),
    );
    if (results.length == 40) break;
  }
  return results;
}

List<PodcastIndexPodcast> parsePodcastIndexTrendingResponse(
  Map<String, dynamic> data,
) {
  final rawFeeds = data['feeds'];
  if (rawFeeds is! List) return const [];
  final results = <PodcastIndexPodcast>[];
  final seenFeeds = <String>{};
  for (final raw in rawFeeds) {
    if (raw is! Map) continue;
    final item = Map<String, dynamic>.from(raw);
    final feedUrl =
        _stringValue(item['url']) ??
        _stringValue(item['originalUrl']) ??
        _stringValue(item['feedUrl']);
    final title =
        _stringValue(item['title']) ??
        _stringValue(item['collectionName']) ??
        _stringValue(item['trackName']);
    if (feedUrl == null || title == null || !seenFeeds.add(_feedKey(feedUrl))) {
      continue;
    }
    final categories = item['categories'];
    final genres = categories is Map
        ? categories.values
              .map(_stringValue)
              .whereType<String>()
              .toList(growable: false)
        : categories is List
        ? categories
              .map(_stringValue)
              .whereType<String>()
              .toList(growable: false)
        : const <String>[];
    results.add(
      PodcastIndexPodcast(
        id: (item['id'] ?? feedUrl).toString(),
        title: title,
        author: _stringValue(item['author']) ?? _stringValue(item['ownerName']),
        feedUrl: feedUrl,
        imageUrl: _stringValue(item['image']) ?? _stringValue(item['artwork']),
        genres: genres,
        episodeCount: _intValue(item['episodeCount']),
        language: _stringValue(item['language']),
        newestEpisodeAt: _timestampValue(item['newestItemPublishTime']),
      ),
    );
  }
  return results;
}

class _DiscoveryCandidate {
  final PodcastIndexPodcast podcast;
  double trendingScore;
  double directoryScore;
  PodcastDiscoverySeed? personalSeed;
  String? explorationContext;

  _DiscoveryCandidate({required this.podcast})
    : trendingScore = 0,
      directoryScore = 0;
}

void _addDiscoveryCandidate(
  Map<String, _DiscoveryCandidate> candidates,
  PodcastIndexPodcast podcast, {
  double trendingScore = 0,
  double directoryScore = 0,
  PodcastDiscoverySeed? personalSeed,
  String? explorationContext,
}) {
  final key = _feedKey(podcast.feedUrl);
  final candidate = candidates.putIfAbsent(
    key,
    () => _DiscoveryCandidate(podcast: podcast),
  );
  candidate.trendingScore = math.max(candidate.trendingScore, trendingScore);
  candidate.directoryScore = math.max(candidate.directoryScore, directoryScore);
  if (candidate.personalSeed == null ||
      (personalSeed?.engagement ?? 0) >
          (candidate.personalSeed?.engagement ?? 0)) {
    candidate.personalSeed = personalSeed;
  }
  candidate.explorationContext ??= explorationContext;
}

List<PodcastIndexRecommendation> _diversifyRecommendations(
  List<PodcastIndexRecommendation> ranked,
  int limit,
) {
  final selected = <PodcastIndexRecommendation>[];
  final deferred = <PodcastIndexRecommendation>[];
  final genreCounts = <String, int>{};
  for (final recommendation in ranked) {
    final primaryGenre = recommendation.podcast.genres.firstOrNull
        ?.toLowerCase();
    if (primaryGenre != null && (genreCounts[primaryGenre] ?? 0) >= 2) {
      deferred.add(recommendation);
      continue;
    }
    selected.add(recommendation);
    if (primaryGenre != null) {
      genreCounts[primaryGenre] = (genreCounts[primaryGenre] ?? 0) + 1;
    }
    if (selected.length == limit) return selected;
  }
  for (final recommendation in deferred) {
    selected.add(recommendation);
    if (selected.length == limit) break;
  }
  return selected;
}

List<String> _fallbackDiscoveryTerms(String? language) => switch (language) {
  'zh' => const ['中文 播客', '科技 播客', '文化 播客'],
  'ja' => const ['日本語 ポッドキャスト', 'テクノロジー'],
  'es' => const ['podcast educación', 'podcast tecnología'],
  'de' => const ['Podcast Bildung', 'Podcast Technologie'],
  _ => const ['education podcast', 'technology podcast', 'culture podcast'],
};

double _rankScore(int index, int length) {
  if (length <= 1) return 1;
  return 1 - index / (length - 1);
}

double _freshnessScore(int timestamp) {
  if (timestamp <= 0) return 0.45;
  final age = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
  );
  if (age.inDays <= 7) return 1;
  if (age.inDays <= 30) return 0.8;
  if (age.inDays <= 90) return 0.55;
  if (age.inDays <= 180) return 0.25;
  return 0;
}

double _stableExplorationScore(String value) {
  var hash = 17;
  for (final codeUnit in value.codeUnits) {
    hash = (hash * 37 + codeUnit) & 0x7fffffff;
  }
  return (hash % 1000) / 999;
}

String? _normalizeLanguage(String? language) {
  final value = language?.trim().toLowerCase();
  if (value == null || value.isEmpty) return null;
  return value.split(RegExp('[-_]')).first;
}

String _feedKey(String value) =>
    value.trim().toLowerCase().replaceFirst(RegExp(r'/$'), '');

bool _sameFeed(String left, String right) => _feedKey(left) == _feedKey(right);

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

int _timestampValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  final parsedInt = int.tryParse(value?.toString() ?? '');
  if (parsedInt != null) return parsedInt;
  final parsedDate = DateTime.tryParse(value?.toString() ?? '');
  return parsedDate == null ? 0 : parsedDate.millisecondsSinceEpoch ~/ 1000;
}
