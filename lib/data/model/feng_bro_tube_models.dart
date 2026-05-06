class FengBroTubeChannel {
  final String id;
  final String name;
  final String url;

  const FengBroTubeChannel({
    required this.id,
    required this.name,
    required this.url,
  });
}

class FengBroTubeVideo {
  final String id;
  final String channelId;
  final String channelName;
  final String title;
  final String url;
  final DateTime publishedAt;
  final String thumbnailUrl;
  final String description;

  const FengBroTubeVideo({
    required this.id,
    required this.channelId,
    required this.channelName,
    required this.title,
    required this.url,
    required this.publishedAt,
    required this.thumbnailUrl,
    required this.description,
  });

  bool isWithin(Duration duration, DateTime now) {
    return now.difference(publishedAt).inMilliseconds >= 0 &&
        now.difference(publishedAt) <= duration;
  }
}

class FengBroTubeChannelResult {
  final FengBroTubeChannel channel;
  final List<FengBroTubeVideo> videos;
  final String? warning;

  const FengBroTubeChannelResult({
    required this.channel,
    required this.videos,
    this.warning,
  });
}

class FengBroTubeSummary {
  final DateTime fetchedAt;
  final List<FengBroTubeChannelResult> channels;

  const FengBroTubeSummary({required this.fetchedAt, required this.channels});

  List<FengBroTubeVideo> recentVideos({
    Duration within = const Duration(days: 3),
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final videos =
        channels
            .expand((channel) => channel.videos)
            .where((video) => video.isWithin(within, current))
            .toList()
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return videos;
  }
}
