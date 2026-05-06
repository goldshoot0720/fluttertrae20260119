import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/model/feng_bro_tube_models.dart';
import '../data/service/feng_bro_tube_service.dart';

class FengBroTubeScreen extends StatefulWidget {
  const FengBroTubeScreen({super.key});

  @override
  State<FengBroTubeScreen> createState() => _FengBroTubeScreenState();
}

class _FengBroTubeScreenState extends State<FengBroTubeScreen> {
  final FengBroTubeService _service = FengBroTubeService();
  FengBroTubeSummary? _summary;
  bool _isLoading = true;
  String _status = '正在載入鋒兄Tube...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _status = '正在抓取各頻道最新影片...';
    });

    try {
      final summary = await _service.fetchLatest();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _isLoading = false;
        _status = '已更新 ${summary.channels.length} 個頻道';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _status = '載入失敗：$e';
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final recent = summary?.recentVideos() ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text(
          '鋒兄Tube',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildHeader(recent),
            const SizedBox(height: 14),
            _buildStatusCard(summary, recent),
            const SizedBox(height: 14),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (summary == null)
              _buildEmptyCard()
            else
              ...summary.channels.map(_buildChannelSection),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(List<FengBroTubeVideo> recent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2F2A),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.ondemand_video_rounded,
              color: Color(0xFF9FF7DF),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '鋒兄Tube',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  recent.isEmpty
                      ? '顯示指定頻道最新影片，每個頻道最多 10 部。'
                      : '3 天內有 ${recent.length} 部新影片，已整理在首頁通知與本頁摘要。',
                  style: const TextStyle(
                    color: Color(0xFFD7FFF4),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    FengBroTubeSummary? summary,
    List<FengBroTubeVideo> recent,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                recent.isEmpty
                    ? Icons.check_circle_rounded
                    : Icons.notifications_active_rounded,
                color: recent.isEmpty
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _status,
                  style: const TextStyle(
                    color: Color(0xFF173832),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (summary != null) ...[
            const SizedBox(height: 8),
            Text(
              '更新時間：${DateFormat('yyyy/MM/dd HH:mm').format(summary.fetchedAt)}',
              style: const TextStyle(color: Color(0xFF576B66)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricChip('頻道', '${summary.channels.length}'),
                _buildMetricChip(
                  '影片',
                  '${summary.channels.expand((c) => c.videos).length}',
                ),
                _buildMetricChip('3天新片', '${recent.length}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6F4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDCE8E4)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Color(0xFF173832),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildChannelSection(FengBroTubeChannelResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.video_collection_rounded,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.channel.name,
                  style: const TextStyle(
                    color: Color(0xFF173832),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openUrl(result.channel.url),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('頻道'),
              ),
            ],
          ),
          if (result.warning != null) ...[
            const SizedBox(height: 8),
            Text(
              '載入警告：${result.warning}',
              style: const TextStyle(color: Color(0xFFB45309)),
            ),
          ],
          if (result.videos.isEmpty && result.warning == null) ...[
            const SizedBox(height: 8),
            const Text('目前沒有抓到影片。', style: TextStyle(color: Color(0xFF576B66))),
          ],
          const SizedBox(height: 10),
          ...result.videos.map(_buildVideoTile),
        ],
      ),
    );
  }

  Widget _buildVideoTile(FengBroTubeVideo video) {
    final isNew = video.isWithin(
      FengBroTubeService.recentWindow,
      DateTime.now(),
    );
    return InkWell(
      onTap: () => _openUrl(video.url),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isNew ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAF9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isNew ? const Color(0xFFF5C38A) : const Color(0xFFDCE8E4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 96,
              height: 54,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFE5ECE9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: video.thumbnailUrl.isEmpty
                  ? const Icon(Icons.play_circle_fill_rounded)
                  : Image.network(
                      video.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) =>
                          const Icon(Icons.play_circle_fill_rounded),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isNew) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '新片',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          DateFormat(
                            'yyyy/MM/dd HH:mm',
                          ).format(video.publishedAt),
                          style: const TextStyle(
                            color: Color(0xFF6A7D78),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF173832),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (video.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      video.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF576B66),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: const Text(
        '尚未載入影片，請重新整理。',
        style: TextStyle(color: Color(0xFF576B66)),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDCE8E4)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0B3B32).withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
