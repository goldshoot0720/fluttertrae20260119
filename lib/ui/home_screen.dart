import 'dart:io';

import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../data/model/subscription_item.dart';
import '../data/service/appwrite_service.dart';
import 'absurd_marriage_reason_screen.dart';
import 'battery_screen.dart';
import 'oil_price_screen.dart';
import 'us_debt_screen.dart';
import 'widgets/subscription_card.dart';
import 'widgets/subscription_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WindowListener, SingleTickerProviderStateMixin {
  final AppwriteService _appwriteService = AppwriteService();
  List<SubscriptionItem> _subscriptions = [];
  bool _isLoading = true;
  bool _bannerDismissed = false;
  late final AnimationController _asciiController;

  @override
  void initState() {
    super.initState();
    _asciiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      _initSystemTray();
    }
    _loadSubscriptions();
  }

  @override
  void dispose() {
    _asciiController.dispose();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final isPreventClose = await windowManager.isPreventClose();
      if (isPreventClose) {
        windowManager.hide();
      }
    }
  }

  Future<void> _initSystemTray() async {
    final systemTray = SystemTray();

    await systemTray.initSystemTray(
      title: 'Subscription Manager',
      iconPath: Platform.isWindows ? r'assets\app_icon.ico' : 'assets/app_icon.png',
    );

    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(label: 'Show', onClicked: (_) => windowManager.show()),
      MenuItemLabel(label: 'Exit', onClicked: (_) => windowManager.close()),
    ]);

    await systemTray.setContextMenu(menu);
    systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        windowManager.show();
      } else if (eventName == kSystemTrayEventRightClick) {
        systemTray.popUpContextMenu();
      }
    });

    await windowManager.setPreventClose(true);
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final subscriptions = await _appwriteService.getSubscriptions();
      subscriptions.sort((a, b) => a.nextDate.compareTo(b.nextDate));
      setState(() {
        _subscriptions = subscriptions;
        _isLoading = false;
        _bannerDismissed = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('載入訂閱資料失敗：$e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _openUsDebt() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const USDebtScreen()),
    );
  }

  Future<void> _openOilPrice() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OilPriceScreen()),
    );
  }

  Future<void> _openAbsurdMarriageReason() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AbsurdMarriageReasonScreen()),
    );
  }

  Future<void> _openBattery() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BatteryScreen()),
    );
  }

  List<SubscriptionItem> _getExpiringItems() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _subscriptions.where((item) {
      final itemDate = DateTime(item.nextDate.year, item.nextDate.month, item.nextDate.day);
      final diff = itemDate.difference(today).inDays;
      return diff >= 0 && diff <= 3;
    }).toList();
  }

  int get _totalMonthlyCost {
    var total = 0;
    for (final item in _subscriptions) {
      total += item.price;
    }
    return total;
  }

  Future<void> _deleteSubscription(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('刪除訂閱'),
        content: const Text(
          '刪除後將無法復原，確定要移除這筆訂閱嗎？',
          style: TextStyle(color: Color(0xFF8899AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _appwriteService.deleteSubscription(id);
      await _loadSubscriptions();
    } catch (e) {
      _showErrorSnackBar('刪除訂閱失敗：$e');
    }
  }

  void _showEditDialog(SubscriptionItem? item) {
    showDialog(
      context: context,
      builder: (context) => SubscriptionDialog(
        item: item,
        onSave: (newItem) async {
          try {
            if (item == null) {
              await _appwriteService.addSubscription(newItem);
            } else {
              newItem.id = item.id;
              await _appwriteService.updateSubscription(newItem);
            }
            if (mounted) {
              Navigator.pop(context);
            }
            await _loadSubscriptions();
          } catch (e) {
            _showErrorSnackBar(item == null ? '新增訂閱失敗：$e' : '更新訂閱失敗：$e');
          }
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF17172B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2A2A4E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8899AA),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final expiringItems = _getExpiringItems();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B38), Color(0xFF131325)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2A2A4E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFengBroAsciiArt(),
                const SizedBox(height: 18),
                const Text(
                  '訂閱總覽',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '集中管理每月支出、扣款日期與重要提醒。',
                  style: TextStyle(
                    color: Color(0xFF9AA7C2),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _buildStatCard(
                      icon: Icons.subscriptions_rounded,
                      label: '訂閱總數',
                      value: '${_subscriptions.length}',
                      color: const Color(0xFF9E8CFF),
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      icon: Icons.payments_rounded,
                      label: '每月支出',
                      value: '\$$_totalMonthlyCost',
                      color: const Color(0xFF6FE7FF),
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      icon: expiringItems.isEmpty
                          ? Icons.check_circle_rounded
                          : Icons.notification_important_rounded,
                      label: '三天內到期',
                      value: '${expiringItems.length}',
                      color: expiringItems.isEmpty
                          ? const Color(0xFF69F0AE)
                          : const Color(0xFFFF8A80),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _openBattery,
                      icon: const Icon(Icons.battery_full_rounded),
                      label: const Text('電池選單'),
                    ),
                    FilledButton.icon(
                      onPressed: _openAbsurdMarriageReason,
                      icon: const Icon(Icons.casino_rounded),
                      label: const Text('最瞎結婚理由'),
                    ),
                    FilledButton.icon(
                      onPressed: _openOilPrice,
                      icon: const Icon(Icons.oil_barrel_rounded),
                      label: const Text('Oil Price'),
                    ),
                    FilledButton.icon(
                      onPressed: _openUsDebt,
                      icon: const Icon(Icons.account_balance_rounded),
                      label: const Text('US Debt'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loadSubscriptions,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重新整理'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (expiringItems.isNotEmpty && !_bannerDismissed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1820),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF5A2937)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF8A80)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '未來 3 天內有 ${expiringItems.length} 筆訂閱即將扣款，請留意付款方式與餘額。',
                      style: const TextStyle(
                        color: Color(0xFFFFD2CC),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _bannerDismissed = true),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFFAA8891)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFengBroAsciiArt() {
    const asciiArt = r'''
 _______ ______ _   _  _____   ______  ______   ____  
|__   __|  ____| \ | |/ ____| |  ____||  __ \ / __ \ 
   | |  | |__  |  \| | |  __  | |__   | |__) | |  | |
   | |  |  __| | . ` | | |_ | |  __|  |  _  /| |  | |
   | |  | |____| |\  | |__| | | |____ | | \ \| |__| |
   |_|  |______|_| \_|\_____| |______||_|  \_\\____/ 
''';

    return AnimatedBuilder(
      animation: _asciiController,
      builder: (context, child) {
        final lift = (_asciiController.value - 0.5) * 8;
        final glow = 0.18 + (_asciiController.value * 0.18);

        return Transform.translate(
          offset: Offset(0, lift),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B1023), Color(0xFF111936), Color(0xFF0C152B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF32446C)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF65FFD5).withOpacity(glow),
                  blurRadius: 28,
                  spreadRadius: 1,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF172445),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF35507F)),
                  ),
                  child: const Text(
                    'ASCII MODE',
                    style: TextStyle(
                      color: Color(0xFF92A9D8),
                      letterSpacing: 2.4,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    asciiArt,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.6,
                      height: 1.08,
                      color: const Color(0xFFA0FFE3),
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: const Color(0xFF5DFFD1).withOpacity(0.55 + glow),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'feng bro',
                        style: TextStyle(
                          color: Color(0xFFE2ECFF),
                          letterSpacing: 3.8,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13203E),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xFF86F8D7),
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF17172B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2A2A4E)),
              ),
              child: const Icon(
                Icons.inbox_rounded,
                size: 48,
                color: Color(0xFF9E8CFF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '目前還沒有任何訂閱',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '按下右下角按鈕，新增第一筆訂閱並開始追蹤扣款時間。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8899AA),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D20),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Subscription Manager',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _isLoading ? null : _loadSubscriptions,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'US Debt',
            onPressed: _openUsDebt,
            icon: const Icon(Icons.account_balance_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSubscriptions,
              child: _subscriptions.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _buildSummarySection(),
                        const SizedBox(height: 40),
                        _buildEmptyState(),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _buildSummarySection(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                          child: Row(
                            children: [
                              const Text(
                                '訂閱清單',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '依最近扣款時間排序',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._subscriptions.asMap().entries.map(
                              (entry) => SubscriptionCard(
                                item: entry.value,
                                index: entry.key,
                                onEdit: () => _showEditDialog(entry.value),
                                onDelete: () => _deleteSubscription(entry.value.id),
                              ),
                            ),
                        const SizedBox(height: 100),
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(null),
        backgroundColor: const Color(0xFF7C4DFF),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
