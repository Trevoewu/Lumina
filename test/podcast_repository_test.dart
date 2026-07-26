import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/podcasts/podcast_index_repository.dart';
import 'package:lumina/data/podcasts/podcast_repository.dart';
import 'package:lumina/services/podcast_transcription_service.dart';
import 'package:lumina/services/playback_progress_service.dart';

void main() {
  test(
    'parses podcast RSS metadata, audio, timestamps, and transcript URL',
    () {
      final feed = parsePodcastFeed('''
      <rss version="2.0"
          xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
          xmlns:content="http://purl.org/rss/1.0/modules/content/"
          xmlns:podcast="https://podcastindex.org/namespace/1.0">
        <channel>
          <title>Example Show</title>
          <itunes:author>Example Author</itunes:author>
          <description><![CDATA[<p>A <b>great</b> show.</p>]]></description>
          <itunes:image href="/cover.jpg" />
          <itunes:category text="Education">
            <itunes:category text="Language Learning" />
          </itunes:category>
          <category>News</category>
          <language>en</language>
          <link>https://example.com/show</link>
          <item>
            <guid>episode-1</guid>
            <title>First Episode</title>
            <content:encoded><![CDATA[<p>Hello <em>world</em>.</p>]]></content:encoded>
            <pubDate>Tue, 21 Jul 2026 17:30:00 +0800</pubDate>
            <itunes:duration>01:02:03</itunes:duration>
            <enclosure url="https://cdn.example.com/e1.mp3" type="audio/mpeg" />
            <podcast:transcript url="/e1.vtt" type="text/vtt" />
          </item>
        </channel>
      </rss>
      ''', feedUrl: 'https://example.com/feed.xml');

      expect(feed.title, 'Example Show');
      expect(feed.author, 'Example Author');
      expect(feed.description, 'A great show.');
      expect(feed.imageUrl, 'https://example.com/cover.jpg');
      expect(feed.categories, ['Education', 'Language Learning', 'News']);
      expect(feed.episodes, hasLength(1));
      final episode = feed.episodes.single;
      expect(episode.guid, 'episode-1');
      expect(episode.description, 'Hello world.');
      expect(
        episode.durationMs,
        const Duration(hours: 1, minutes: 2, seconds: 3).inMilliseconds,
      );
      expect(
        episode.publishedAt,
        DateTime.utc(2026, 7, 21, 9, 30).millisecondsSinceEpoch,
      );
      expect(episode.sourceTranscriptUrl, 'https://example.com/e1.vtt');
    },
  );

  test('preserves HTTPS destinations from RSS description links', () {
    final feed = parsePodcastFeed('''
      <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
        <channel>
          <title>Linked Show</title>
          <description><![CDATA[
            Read the <a href="/about">show website</a>.
          ]]></description>
          <item>
            <guid>linked-episode</guid>
            <title>Linked Episode</title>
            <content:encoded><![CDATA[
              Resources: <a href="https://example.org/notes">episode notes</a>.
            ]]></content:encoded>
            <enclosure url="https://cdn.example.com/linked.mp3" type="audio/mpeg" />
          </item>
        </channel>
      </rss>
    ''', feedUrl: 'https://example.com/feed.xml');

    expect(
      feed.description,
      'Read the show website (https://example.com/about).',
    );
    expect(
      feed.episodes.single.description,
      'Resources: episode notes (https://example.org/notes).',
    );
  });

  test('normalizes feed URLs and rejects unsupported schemes', () {
    expect(
      normalizePodcastFeedUrl('example.com/feed.xml'),
      'https://example.com/feed.xml',
    );
    expect(
      () => normalizePodcastFeedUrl('file:///tmp/feed.xml'),
      throwsFormatException,
    );
  });

  test('decodes persisted podcast categories defensively', () {
    expect(decodePodcastCategories('["Comedy", "News", "comedy"]'), [
      'Comedy',
      'News',
    ]);
    expect(decodePodcastCategories('not-json'), isEmpty);
    expect(decodePodcastCategories(null), isEmpty);
  });

  test(
    'preview playback data stays outside the subscription library',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = PodcastRepository(database);
      const preview = ParsedPodcastFeed(
        title: 'Preview Show',
        author: 'Preview Host',
        description: 'Listen before following.',
        imageUrl: null,
        language: 'en',
        websiteUrl: null,
        categories: ['Comedy'],
        episodes: [
          ParsedPodcastEpisode(
            guid: 'preview-guid',
            title: 'Preview Episode',
            description: '',
            audioUrl: 'https://example.com/preview.mp3',
            imageUrl: null,
            publishedAt: 10,
            durationMs: 60000,
            sourceTranscriptUrl: null,
          ),
        ],
      );

      final result = await repository.storePreview(
        'https://example.com/preview.xml',
        preview,
        categories: const ['News'],
      );

      expect(result.show.subscribedAt, 0);
      expect(await database.getPodcastShows(), isEmpty);
      expect(await database.getRecentPodcastEpisodes(), isEmpty);
      expect(await database.getAllPodcastShows(), hasLength(1));
      expect(
        await database.getRecentPodcastEpisodes(subscribedOnly: false),
        hasLength(1),
      );
      expect(decodePodcastCategories(result.show.categoriesJson), [
        'Comedy',
        'News',
      ]);
    },
  );

  test('parses and deduplicates Podcast Index directory results', () {
    final results = parsePodcastIndexSearchResponse({
      'resultCount': 3,
      'results': [
        {
          'collectionId': 42,
          'collectionName': 'Example Podcast',
          'artistName': 'Example Author',
          'feedUrl': 'https://example.com/feed.xml',
          'artworkUrl600': 'https://example.com/cover.jpg',
          'genres': ['Technology', 'Education'],
          'trackCount': 12,
        },
        {'trackName': 'Duplicate', 'feedUrl': 'https://example.com/feed.xml'},
        {'trackName': 'Missing feed'},
      ],
    });

    expect(results, hasLength(1));
    expect(results.single.id, '42');
    expect(results.single.title, 'Example Podcast');
    expect(results.single.author, 'Example Author');
    expect(results.single.genres, ['Technology', 'Education']);
    expect(results.single.episodeCount, 12);
  });

  test('parses Podcast Index trending feeds and their discovery metadata', () {
    final results = parsePodcastIndexTrendingResponse({
      'feeds': [
        {
          'id': 73,
          'title': 'Trending Show',
          'author': 'Host',
          'url': 'https://example.com/trending.xml',
          'image': 'https://example.com/trending.jpg',
          'language': 'en-US',
          'episodeCount': 42,
          'newestItemPublishTime': 1234,
          'categories': {'77': 'Education', '78': 'Technology'},
        },
      ],
    });

    expect(results, hasLength(1));
    expect(results.single.title, 'Trending Show');
    expect(results.single.language, 'en-US');
    expect(results.single.genres, ['Education', 'Technology']);
    expect(results.single.newestEpisodeAt, 1234);
  });

  test(
    'discovery excludes subscriptions and explains related results',
    () async {
      final repository = _DiscoveryPodcastIndexRepository();
      final recommendations = await repository.discover(
        seeds: const [
          PodcastDiscoverySeed(
            title: 'Example Show',
            feedUrl: 'https://example.com/feed.xml',
            language: 'en',
            engagement: 0.9,
          ),
        ],
        subscribedFeedUrls: const {'https://example.com/feed.xml'},
        preferredLanguage: 'en',
      );

      expect(
        recommendations.map((recommendation) => recommendation.podcast.feedUrl),
        isNot(contains('https://example.com/feed.xml')),
      );
      expect(
        recommendations
            .firstWhere(
              (recommendation) => recommendation.podcast.id == 'related',
            )
            .reason,
        PodcastRecommendationReason.becauseYouListen,
      );
    },
  );

  test('decodes persisted timestamped Whisper segments', () {
    final segments = PodcastTranscriptionService.decodeTranscript(
      '[{"text":"Hello","startMs":120,"endMs":930}]',
    );
    expect(segments, hasLength(1));
    expect(segments.single.text, 'Hello');
    expect(segments.single.startMs, 120);
    expect(segments.single.endMs, 930);
  });

  test('normalizes RSS and device languages for Whisper', () {
    expect(resolveWhisperLanguage('zh-CN'), 'zh');
    expect(resolveWhisperLanguage('eng'), 'en');
    expect(resolveWhisperLanguage(null), 'auto');
    expect(
      resolveWhisperLanguage(
        null,
        fallbackLocale: 'ja_JP',
        supportsAuto: false,
      ),
      'ja',
    );
  });

  test('marks podcast played near the end but not at the start', () {
    expect(isPodcastEpisodePlayed(positionMs: 0, durationMs: 20000), isFalse);
    expect(
      isPodcastEpisodePlayed(positionMs: 19000, durationMs: 20000),
      isTrue,
    );
    expect(
      isPodcastEpisodePlayed(positionMs: 3570000, durationMs: 3600000),
      isTrue,
    );
  });

  test(
    'persists podcast progress and transcript independently from books',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      const show = PodcastShow(
        id: 'show-1',
        feedUrl: 'https://example.com/feed.xml',
        title: 'Example Show',
        description: '',
        subscribedAt: 1,
        lastRefreshedAt: 1,
      );
      const episode = PodcastEpisode(
        id: 'episode-1',
        showId: 'show-1',
        guid: 'guid-1',
        title: 'Episode',
        description: '',
        audioUrl: 'https://example.com/e.mp3',
        publishedAt: 1,
        durationMs: 60000,
        playbackPositionMs: 0,
        lastPlayedAt: 0,
        isPlayed: false,
        transcriptStatus: 'none',
      );

      await database.upsertPodcastShow(show);
      await database.upsertPodcastEpisode(episode);
      await database.updatePodcastProgress(
        episode.id,
        positionMs: 57000,
        isPlayed: true,
      );
      await database.updatePodcastProgress(
        episode.id,
        positionMs: 1000,
        isPlayed: false,
      );
      await database.updatePodcastTranscript(
        episode.id,
        status: 'complete',
        transcriptJson: '[{"text":"Hello","startMs":0,"endMs":900}]',
        language: 'en',
      );

      final updated = await database.getPodcastEpisode(episode.id);
      expect(updated?.playbackPositionMs, 1000);
      expect(updated?.isPlayed, isTrue);
      expect(updated?.transcriptStatus, 'complete');
      expect(updated?.transcriptLanguage, 'en');

      // A later status/error update represents an interrupted chunked run and
      // must leave all transcript chunks that already reached disk visible.
      await database.updatePodcastTranscript(
        episode.id,
        status: 'failed',
        error: 'interrupted',
      );
      final interrupted = await database.getPodcastEpisode(episode.id);
      expect(interrupted?.transcriptStatus, 'failed');
      expect(
        interrupted?.transcriptJson,
        '[{"text":"Hello","startMs":0,"endMs":900}]',
      );
      expect(interrupted?.transcriptLanguage, 'en');
      expect(interrupted?.transcriptError, 'interrupted');

      await database.deletePodcastShowCascade(show.id);
      expect(await database.getPodcastShow(show.id), isNull);
      expect(await database.getPodcastEpisode(episode.id), isNull);
    },
  );
}

class _DiscoveryPodcastIndexRepository extends PodcastIndexRepository {
  _DiscoveryPodcastIndexRepository() : super(apiKey: '', apiSecret: '');

  @override
  Future<List<PodcastIndexPodcast>> search(String query) async {
    if (query == 'Example Show') {
      return const [
        PodcastIndexPodcast(
          id: 'subscribed',
          title: 'Example Show',
          author: 'Example',
          feedUrl: 'https://example.com/feed.xml',
          imageUrl: null,
          genres: ['Education'],
          episodeCount: 20,
          language: 'en',
        ),
        PodcastIndexPodcast(
          id: 'related',
          title: 'Related Learning Show',
          author: 'Teacher',
          feedUrl: 'https://example.com/related.xml',
          imageUrl: null,
          genres: ['Education'],
          episodeCount: 30,
          language: 'en',
        ),
      ];
    }
    return const [
      PodcastIndexPodcast(
        id: 'explore',
        title: 'Explore More',
        author: 'Explorer',
        feedUrl: 'https://example.com/explore.xml',
        imageUrl: null,
        genres: ['Education'],
        episodeCount: 18,
        language: 'en',
      ),
    ];
  }
}
