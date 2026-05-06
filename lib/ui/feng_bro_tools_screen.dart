import 'package:flutter/material.dart';

import 'feng_bro_finance_screen.dart';
import 'feng_bro_tube_screen.dart';
import 'feng_bro_voice_screen.dart';
import 'phone_compare_screen.dart';
import 'price_history_screen.dart';

class FengBroToolsScreen extends StatelessWidget {
  const FengBroToolsScreen({super.key});

  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text(
          '鋒兄工具',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildHero(),
          const SizedBox(height: 16),
          _ToolCard(
            icon: Icons.mic_rounded,
            color: const Color(0xFF0F766E),
            title: '鋒兄語音輸入',
            subtitle:
                '支援首頁、儀表、訂閱、食品、筆記、常用、圖片、影片、音樂、文件、播客、銀行、例行、設定、關於等 15 個模組，語音草稿需雙重確認。',
            onTap: () => _open(context, const FengBroVoiceScreen()),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.account_balance_rounded,
            color: const Color(0xFF2563EB),
            title: '鋒兄金融',
            subtitle:
                '追蹤 CNBC 金融行情：亞股、美股、原油、黃金、30 年美債、VIX、BTC、ETH，創 52 週新高或新低時自動標註。',
            onTap: () => _open(context, const FengBroFinanceScreen()),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.ondemand_video_rounded,
            color: const Color(0xFFDC2626),
            title: '鋒兄Tube',
            subtitle: '追蹤指定 YouTube 頻道，每個頻道顯示最新 10 部影片，首頁提示 3 天內新片。',
            onTap: () => _open(context, const FengBroTubeScreen()),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.query_stats_rounded,
            color: const Color(0xFFD9702F),
            title: '鋒兄比價',
            subtitle: '貼上商品連結或 BigGo history_id，查看歷史價格走勢與統計。',
            onTap: () => _open(context, const PriceHistoryScreen()),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.smartphone_rounded,
            color: const Color(0xFF2563EB),
            title: '手機比價',
            subtitle: '查詢 Landtop 與 JYES 手機售價，快速比較建議售價、店家價與最低價。',
            onTap: () => _open(context, const PhoneCompareScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2F2A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FENG BRO TOOLBOX',
            style: TextStyle(
              color: Color(0xFF90F6DD),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '鋒兄工具',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '把常用比價與語音輸入工具集中在這裡，重要語音指令都先整理成草稿並雙重確認。',
            style: TextStyle(color: Color(0xFFD6FFF4), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDCE8E4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B3B32).withOpacity(0.06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF173832),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF576B66),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF6A7D78)),
          ],
        ),
      ),
    );
  }
}
