import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../database/app_database.dart';

class PodcastImportResult {
  final PodcastShow show;
  final int importedEpisodes;

  const PodcastImportResult({
    required this.show,
    required this.importedEpisodes,
  });
}

class PodcastRepository {
  final AppDatabase database;
  final Dio _dio;

  PodcastRepository(this.database, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              headers: const {
                'user-agent': 'Lumina/1.0 (+local podcast reader)',
                'accept': 'application/rss+xml, application/xml, text/xml, */*',
              },
            ),
          );

  Future<PodcastImportResult> subscribe(String input) async {
    final feedUrl = normalizePodcastFeedUrl(input);
    final existing = await database.getPodcastShowByFeedUrl(feedUrl);
    return _fetchAndStore(feedUrl, existing: existing);
  }

  Future<PodcastImportResult> refresh(PodcastShow show) =>
      _fetchAndStore(show.feedUrl, existing: show);

  Future<void> refreshAll() async {
    for (final show in await database.getPodcastShows()) {
      await refresh(show);
    }
  }

  Future<PodcastImportResult> _fetchAndStore(
    String feedUrl, {
    PodcastShow? existing,
  }) async {
    final response = await _dio.get<String>(
      feedUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final source = response.data?.trim();
    if (source == null || source.isEmpty) {
      throw const FormatException('RSS 地址没有返回内容。');
    }

    // Resolve relative artwork/enclosure URLs against the final location when
    // a publisher redirects its public feed address.
    final parsed = parsePodcastFeed(
      source,
      feedUrl: response.realUri.toString(),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final showId = existing?.id ?? _stableId('show:$feedUrl');
    final show = PodcastShow(
      id: showId,
      feedUrl: feedUrl,
      title: parsed.title,
      author: parsed.author,
      description: parsed.description,
      imageUrl: parsed.imageUrl,
      language: parsed.language,
      websiteUrl: parsed.websiteUrl,
      subscribedAt: existing?.subscribedAt ?? now,
      lastRefreshedAt: now,
    );

    await database.transaction(() async {
      await database.upsertPodcastShow(show);
      for (final item in parsed.episodes) {
        final old = await database.getPodcastEpisodeByGuid(showId, item.guid);
        final episode = PodcastEpisode(
          id: old?.id ?? _stableId('episode:$showId:${item.guid}'),
          showId: showId,
          guid: item.guid,
          title: item.title,
          description: item.description,
          audioUrl: item.audioUrl,
          imageUrl: item.imageUrl ?? show.imageUrl,
          publishedAt: item.publishedAt,
          durationMs: item.durationMs,
          playbackPositionMs: old?.playbackPositionMs ?? 0,
          lastPlayedAt: old?.lastPlayedAt ?? 0,
          isPlayed: old?.isPlayed ?? false,
          localAudioPath: old?.localAudioPath,
          transcriptJson: old?.transcriptJson,
          transcriptLanguage: old?.transcriptLanguage,
          transcriptStatus: old?.transcriptStatus ?? 'none',
          transcriptError: old?.transcriptError,
          sourceTranscriptUrl:
              item.sourceTranscriptUrl ?? old?.sourceTranscriptUrl,
        );
        await database.upsertPodcastEpisode(episode);
      }
    });

    return PodcastImportResult(
      show: show,
      importedEpisodes: parsed.episodes.length,
    );
  }
}

String normalizePodcastFeedUrl(String input) {
  var value = input.trim();
  if (value.isEmpty) throw const FormatException('请输入 Podcast RSS 地址。');
  if (!value.contains('://')) value = 'https://$value';
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw const FormatException('请输入有效的 HTTP 或 HTTPS RSS 地址。');
  }
  return uri.toString();
}

class ParsedPodcastFeed {
  final String title;
  final String? author;
  final String description;
  final String? imageUrl;
  final String? language;
  final String? websiteUrl;
  final List<ParsedPodcastEpisode> episodes;

  const ParsedPodcastFeed({
    required this.title,
    required this.author,
    required this.description,
    required this.imageUrl,
    required this.language,
    required this.websiteUrl,
    required this.episodes,
  });
}

class ParsedPodcastEpisode {
  final String guid;
  final String title;
  final String description;
  final String audioUrl;
  final String? imageUrl;
  final int publishedAt;
  final int durationMs;
  final String? sourceTranscriptUrl;

  const ParsedPodcastEpisode({
    required this.guid,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.imageUrl,
    required this.publishedAt,
    required this.durationMs,
    required this.sourceTranscriptUrl,
  });
}

ParsedPodcastFeed parsePodcastFeed(String source, {required String feedUrl}) {
  final document = XmlDocument.parse(source);
  final channel = document.descendantElements
      .where((element) => element.name.local == 'channel')
      .firstOrNull;
  if (channel == null) {
    throw const FormatException('目前仅支持标准 RSS Podcast Feed。');
  }

  final title = _childText(channel, 'title');
  if (title == null || title.isEmpty) {
    throw const FormatException('RSS 缺少节目标题。');
  }

  final channelImage = _children(channel, 'image')
      .map(
        (element) => _attribute(element, 'href') ?? _childText(element, 'url'),
      )
      .whereType<String>()
      .firstOrNull;
  final episodes = <ParsedPodcastEpisode>[];
  for (final item in _children(channel, 'item')) {
    final enclosure = _children(
      item,
      'enclosure',
    ).where((element) => _attribute(element, 'url') != null).firstOrNull;
    final mediaContent = _children(
      item,
      'content',
    ).where((element) => _attribute(element, 'url') != null).firstOrNull;
    final audioUrl = enclosure == null
        ? _attribute(mediaContent, 'url')
        : _attribute(enclosure, 'url');
    if (audioUrl == null || audioUrl.isEmpty) continue;

    final episodeTitle = _childText(item, 'title') ?? '未命名单集';
    final guid = _childText(item, 'guid')?.trim();
    final imageUrl = _children(item, 'image')
        .map((element) => _attribute(element, 'href'))
        .whereType<String>()
        .firstOrNull;
    final transcriptUrl = _children(item, 'transcript')
        .map((element) => _attribute(element, 'url'))
        .whereType<String>()
        .firstOrNull;
    final description = _plainText(
      _childText(item, 'encoded') ??
          _childText(item, 'description') ??
          _childText(item, 'summary') ??
          '',
    );

    episodes.add(
      ParsedPodcastEpisode(
        guid: guid == null || guid.isEmpty ? audioUrl : guid,
        title: episodeTitle,
        description: description,
        audioUrl: _resolveUrl(feedUrl, audioUrl),
        imageUrl: imageUrl == null ? null : _resolveUrl(feedUrl, imageUrl),
        publishedAt: _parsePodcastDate(
          _childText(item, 'pubDate') ?? _childText(item, 'published'),
        ),
        durationMs: _parsePodcastDuration(_childText(item, 'duration')),
        sourceTranscriptUrl: transcriptUrl == null
            ? null
            : _resolveUrl(feedUrl, transcriptUrl),
      ),
    );
  }

  return ParsedPodcastFeed(
    title: title,
    author:
        _childText(channel, 'author') ?? _childText(channel, 'managingEditor'),
    description: _plainText(_childText(channel, 'description') ?? ''),
    imageUrl: channelImage == null ? null : _resolveUrl(feedUrl, channelImage),
    language: _childText(channel, 'language'),
    websiteUrl: _childText(channel, 'link'),
    episodes: episodes,
  );
}

Iterable<XmlElement> _children(XmlElement parent, String localName) =>
    parent.childElements.where((element) => element.name.local == localName);

String? _childText(XmlElement parent, String localName) {
  for (final child in _children(parent, localName)) {
    final value = child.innerText.trim();
    if (value.isNotEmpty) return value;
  }
  return null;
}

String? _attribute(XmlElement? element, String localName) {
  if (element == null) return null;
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) {
      final value = attribute.value.trim();
      if (value.isNotEmpty) return value;
    }
  }
  return null;
}

String _plainText(String markup) =>
    html_parser
        .parseFragment(markup)
        .text
        ?.replaceAll(RegExp(r'\s+'), ' ')
        .trim() ??
    '';

String _resolveUrl(String base, String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null) return value.trim();
  if (uri.hasScheme) return uri.toString();
  return Uri.parse(base).resolveUri(uri).toString();
}

int _parsePodcastDuration(String? value) {
  if (value == null || value.trim().isEmpty) return 0;
  final parts = value.trim().split(':');
  if (parts.length == 1) {
    return ((double.tryParse(parts.single) ?? 0) * 1000).round();
  }
  var seconds = 0.0;
  for (final part in parts) {
    seconds = seconds * 60 + (double.tryParse(part) ?? 0);
  }
  return (seconds * 1000).round();
}

int _parsePodcastDate(String? value) {
  if (value == null || value.trim().isEmpty) return 0;
  final source = value.trim();
  try {
    return HttpDate.parse(source).millisecondsSinceEpoch;
  } catch (_) {}

  final direct = DateTime.tryParse(source);
  if (direct != null) return direct.millisecondsSinceEpoch;

  final normalized = source.replaceFirst(RegExp(r'^[A-Za-z]{3},\s*'), '');
  final match = RegExp(
    r'^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
    r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s+'
    r'([+-])(\d{2})(\d{2})$',
  ).firstMatch(normalized);
  if (match == null) return 0;
  const months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final month = months[match.group(2)!.toLowerCase()];
  if (month == null) return 0;
  final local = DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.tryParse(match.group(6) ?? '') ?? 0,
  );
  final offset = Duration(
    hours: int.parse(match.group(8)!),
    minutes: int.parse(match.group(9)!),
  );
  return (match.group(7) == '+' ? local.subtract(offset) : local.add(offset))
      .millisecondsSinceEpoch;
}

String _stableId(String value) => sha256.convert(utf8.encode(value)).toString();
