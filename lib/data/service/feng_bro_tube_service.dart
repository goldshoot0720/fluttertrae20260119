import 'package:http/http.dart' as http;

import '../model/feng_bro_tube_models.dart';

class FengBroTubeService {
  static const Duration recentWindow = Duration(days: 3);
  static const int defaultVideoLimit = 10;
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

  static const List<FengBroTubeChannel> channels = [
    FengBroTubeChannel(
      id: 'sjdiao',
      name: 'SJdiao',
      url: 'https://www.youtube.com/@SJdiao/videos',
    ),
    FengBroTubeChannel(
      id: 'henren778',
      name: '一个狠人',
      url: 'https://www.youtube.com/@henren778',
    ),
    FengBroTubeChannel(
      id: 'libertas1984',
      name: 'Libertas 1984',
      url: 'https://www.youtube.com/@libertas1984/videos',
    ),
    FengBroTubeChannel(
      id: 'sunlao',
      name: '孫老',
      url: 'https://www.youtube.com/@sunlao/videos',
    ),
    FengBroTubeChannel(
      id: 'torontobigface',
      name: '多倫多方臉',
      url: 'https://www.youtube.com/@Torontobigface/videos',
    ),
    FengBroTubeChannel(
      id: 'junyulan',
      name: '君宇蘭',
      url: 'https://www.youtube.com/@junyulan/videos',
    ),
    FengBroTubeChannel(
      id: 'blackwhite-raven',
      name: '黑白烏鴉',
      url: 'https://www.youtube.com/@blackwhite_raven/videos',
    ),
    FengBroTubeChannel(
      id: 'quedaren',
      name: '缺德人',
      url: 'https://www.youtube.com/@quedaren/videos',
    ),
    FengBroTubeChannel(
      id: 'quark-talk',
      name: '夸克说',
      url: 'https://www.youtube.com/@%E5%A4%B8%E5%85%8B%E8%AF%B4',
    ),
    FengBroTubeChannel(
      id: 'meow-watch',
      name: '喵喵看一看',
      url:
          'https://www.youtube.com/@%E5%96%B5%E5%96%B5%E7%9C%8B%E4%B8%80%E7%9C%8B/videos',
    ),
  ];

  Future<FengBroTubeSummary> fetchLatest({
    int limit = defaultVideoLimit,
  }) async {
    final uniqueChannels = <String, FengBroTubeChannel>{
      for (final channel in channels) channel.id: channel,
    }.values;
    final results = await Future.wait(
      uniqueChannels.map((channel) => _fetchChannel(channel, limit: limit)),
    );

    return FengBroTubeSummary(fetchedAt: DateTime.now(), channels: results);
  }

  Future<FengBroTubeChannelResult> _fetchChannel(
    FengBroTubeChannel channel, {
    required int limit,
  }) async {
    try {
      final channelId = await _resolveChannelId(channel.url);
      final videos = await _fetchRssVideos(
        channel: channel,
        channelId: channelId,
        limit: limit,
      );
      return FengBroTubeChannelResult(channel: channel, videos: videos);
    } catch (e) {
      return FengBroTubeChannelResult(
        channel: channel,
        videos: const [],
        warning: '$e',
      );
    }
  }

  Future<String> _resolveChannelId(String url) async {
    final html = await _fetchText(_normalizeChannelUrl(url));
    final patterns = [
      RegExp(r'"channelId":"(UC[\w-]+)"'),
      RegExp(r'"externalId":"(UC[\w-]+)"'),
      RegExp(r'<meta itemprop="channelId" content="(UC[\w-]+)">'),
      RegExp(r'channel_id=(UC[\w-]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        return match.group(1)!;
      }
    }

    throw Exception('無法解析頻道 ID');
  }

  Future<List<FengBroTubeVideo>> _fetchRssVideos({
    required FengBroTubeChannel channel,
    required String channelId,
    required int limit,
  }) async {
    final rss = await _fetchText(
      'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId',
    );
    final entries = RegExp(
      r'<entry>([\s\S]*?)<\/entry>',
      multiLine: true,
    ).allMatches(rss);

    final videos = <FengBroTubeVideo>[];
    for (final entryMatch in entries.take(limit)) {
      final entry = entryMatch.group(1) ?? '';
      final videoId = _tagValue(entry, 'yt:videoId');
      final title = _decodeXml(_tagValue(entry, 'title'));
      final published = DateTime.tryParse(_tagValue(entry, 'published'));
      final link =
          RegExp(
            r'<link rel="alternate" href="([^"]+)"',
          ).firstMatch(entry)?.group(1) ??
          'https://www.youtube.com/watch?v=$videoId';
      final thumbnail =
          RegExp(
            r'<media:thumbnail url="([^"]+)"',
          ).firstMatch(entry)?.group(1) ??
          '';
      final description = _decodeXml(_tagValue(entry, 'media:description'));
      final authorName = _decodeXml(_tagValue(entry, 'name'));

      if (videoId.isEmpty || title.isEmpty || published == null) {
        continue;
      }

      videos.add(
        FengBroTubeVideo(
          id: videoId,
          channelId: channel.id,
          channelName: authorName.isEmpty ? channel.name : authorName,
          title: title,
          url: _decodeXml(link),
          publishedAt: published.toLocal(),
          thumbnailUrl: _decodeXml(thumbnail),
          description: description,
        ),
      );
    }
    return videos;
  }

  Future<String> _fetchText(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: const {
        'User-Agent': _userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
      },
    );

    if (response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return response.body;
  }

  String _normalizeChannelUrl(String url) {
    final uri = Uri.parse(url);
    if (uri.path.endsWith('/videos')) {
      return url;
    }
    if (uri.host.contains('youtube.com') && uri.path.startsWith('/@')) {
      return uri.replace(path: '${uri.path}/videos').toString();
    }
    return url;
  }

  String _tagValue(String xml, String tag) {
    return RegExp(
          '<$tag(?: [^>]*)?>([\\s\\S]*?)<\\/$tag>',
          multiLine: true,
        ).firstMatch(xml)?.group(1)?.trim() ??
        '';
  }

  String _decodeXml(String value) {
    return value
        .replaceAll('<![CDATA[', '')
        .replaceAll(']]>', '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .trim();
  }
}
