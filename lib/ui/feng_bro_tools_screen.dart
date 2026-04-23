import 'package:flutter/material.dart';

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
            icon: Icons.query_stats_rounded,
            color: const Color(0xFFD9702F),
            title: '鋒兄比價',
            subtitle: '貼上商品連結或 BigGo history_id，查看歷史價格走勢與統計。',
            onTap: () => _open(context, const PriceHistoryScreen()),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.smartphone_rounded,
            color: const Color(0xFF0F766E),
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
            '把常用比價工具集中在這裡，商品歷史價與手機店家價都能直接查。',
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
