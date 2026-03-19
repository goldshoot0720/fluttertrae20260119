import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import '../data/model/subscription_item.dart';
import '../data/service/appwrite_service.dart';
import 'oil_monitor_screen.dart';
import 'widgets/subscription_card.dart';
import 'widgets/subscription_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener, TickerProviderStateMixin {
  final AppwriteService _appwriteService = AppwriteService();
  List<SubscriptionItem> _subscriptions = [];
  bool _isLoading = true;
  bool _bannerDismissed = false;
  late AnimationController _bannerAnimController;
  late Animation<double> _bannerAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _bannerAnimController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _bannerAnimation = CurvedAnimation(
      parent: _bannerAnimController,
      curve: Curves.easeOutBack,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      _initSystemTray();
    }
    _loadSubscriptions();
  }

  @override
  void dispose() {
    _bannerAnimController.dispose();
    _pulseController.dispose();
    _fabController.dispose();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      bool isPreventClose = await windowManager.isPreventClose();
      if (isPreventClose) {
        windowManager.hide();
      }
    }
  }

  Future<void> _initSystemTray() async {
    final SystemTray systemTray = SystemTray();

    await systemTray.initSystemTray(
      title: "Subscription Manager",
      iconPath: Platform.isWindows ? r'assets\app_icon.ico' : 'assets/app_icon.png',
    );

    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(label: 'Show', onClicked: (menuItem) => windowManager.show()),
      MenuItemLabel(label: 'Exit', onClicked: (menuItem) => windowManager.close()),
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
      final subs = await _appwriteService.getSubscriptions();
      setState(() {
        _subscriptions = subs;
        _isLoading = false;
        _bannerDismissed = false;
      });
      // Animate banner in if there are expiring items
      if (_getExpiringItems().isNotEmpty) {
        _bannerAnimController.forward(from: 0);
      }
      _fabController.forward(from: 0);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('載入失敗: $e')),
              ],
            ),
            backgroundColor: const Color(0xFF1A1A2E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _openOilMonitor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OilMonitorScreen(),
      ),
    );
  }

  List<SubscriptionItem> _getExpiringItems() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _subscriptions.where((item) {
      final itemDate = DateTime(item.nextDate.year, item.nextDate.month, item.nextDate.day);
      final diff = itemDate.difference(today).inDays;
      return diff >= 0 && diff <= 3;
    }).toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
  }

  int get _totalMonthlyCost {
    int total = 0;
    for (var item in _subscriptions) {
      total += item.price;
    }
    return total;
  }

  Future<void> _deleteSubscription(String id) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFFF5252), size: 20),
            ),
            const SizedBox(width: 10),
            const Text('確認刪除', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text('確定要刪除此訂閱嗎？此操作無法復原。',
            style: TextStyle(color: Color(0xFF8899AA))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Color(0xFF8899AA))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('刪除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _appwriteService.deleteSubscription(id);
        _loadSubscriptions();
      } catch (e) {
        _showErrorSnackBar('刪除失敗: $e');
      }
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
            _loadSubscriptions();
            Navigator.pop(context);
          } catch (e) {
            _showErrorSnackBar(item == null ? '新增失敗: $e' : '更新失敗: $e');
          }
        },
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A3E), Color(0xFF141430), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2A2A4E).withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFF).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.subscriptions_rounded,
            label: '訂閱總數',
            value: '${_subscriptions.length}',
            color: const Color(0xFF7C4DFF),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.payments_rounded,
            label: '總費用',
            value: '\$${_totalMonthlyCost}',
            color: const Color(0xFF00E5FF),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: _getExpiringItems().isNotEmpty
                ? Icons.notifications_active_rounded
                : Icons.check_circle_rounded,
            label: '即將到期',
            value: '${_getExpiringItems().length}',
            color: _getExpiringItems().isNotEmpty
                ? const Color(0xFFFF5252)
                : const Color(0xFF69F0AE),
            isPulsing: _getExpiringItems().isNotEmpty,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isPulsing = false,
  }) {
    Widget iconWidget = Icon(icon, color: color, size: 22);
    if (isPulsing) {
      iconWidget = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.9 + (_pulseAnimation.value * 0.15),
            child: Icon(icon, color: color.withOpacity(0.7 + _pulseAnimation.value * 0.3), size: 22),
          );
        },
      );
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.12),
              color.withOpacity(0.04),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            iconWidget,
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8899AA),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringBanner() {
    final expiringItems = _getExpiringItems();
    if (expiringItems.isEmpty || _bannerDismissed) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return SizeTransition(
      sizeFactor: _bannerAnimation,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3A1220), Color(0xFF2A1535), Color(0xFF1A1A3E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.35), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5252).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252).withOpacity(0.1 + _pulseAnimation.value * 0.15),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF5252).withOpacity(_pulseAnimation.value * 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFFF5252), size: 17),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '⚠️ ${expiringItems.length} 個訂閱即將到期',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFFFF8A80),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _bannerDismissed = true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF556677)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2A2A4E), height: 1, indent: 16, endIndent: 16),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: min(expiringItems.length * 42.0, 180)),
              child: ListView.builder(
                shrinkWrap: true,
                physics: expiringItems.length > 4
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 2),
                itemCount: expiringItems.length,
                itemBuilder: (context, index) {
                  final item = expiringItems[index];
                  final itemDate = DateTime(item.nextDate.year, item.nextDate.month, item.nextDate.day);
                  final daysLeft = itemDate.difference(today).inDays;
                  final daysText = daysLeft == 0
                      ? '今天到期'
                      : daysLeft == 1
                          ? '明天到期'
                          : '$daysLeft 天後到期';
                  final dateStr =
                      '${item.nextDate.year}/${item.nextDate.month.toString().padLeft(2, '0')}/${item.nextDate.day.toString().padLeft(2, '0')}';

                  final urgencyColor = daysLeft == 0
                      ? const Color(0xFFFF5252)
                      : daysLeft == 1
                          ? const Color(0xFFFF9800)
                          : const Color(0xFFFFD740);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [urgencyColor, urgencyColor.withOpacity(0.3)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                urgencyColor.withOpacity(0.25),
                                urgencyColor.withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: urgencyColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            daysText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: urgencyColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF667788)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '\$${item.price}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Column(
      children: [
        // Shimmer header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: List.generate(3, (index) => Expanded(
              child: Container(
                margin: EdgeInsets.only(left: index > 0 ? 12 : 0),
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )),
          ),
        ),
        // Shimmer cards
        ...List.generate(5, (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withOpacity(0.6),
            borderRadius: BorderRadius.circular(18),
          ),
        )),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C4DFF).withOpacity(0.1),
                  const Color(0xFF448AFF).withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_rounded,
              size: 56,
              color: Color(0xFF7C4DFF),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '尚無訂閱項目',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFFCCDDEE),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '點擊右下角按鈕新增第一個訂閱',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF667788),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expiringCount = _getExpiringItems().length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D20),
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.subscriptions_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Subscription Manager',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        actions: [
          // Expiring badge
          if (expiringCount > 0)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252).withOpacity(0.1 + _pulseAnimation.value * 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFF5252)),
                      const SizedBox(width: 4),
                      Text(
                        '$expiringCount',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF5252),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          // Total count badge
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.list_alt, size: 14, color: Color(0xFF7C4DFF)),
                const SizedBox(width: 4),
                Text(
                  '${_subscriptions.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C4DFF),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : _loadSubscriptions,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A2A4E).withOpacity(0.5)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF7C4DFF),
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF8899AA)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: PopupMenuButton<String>(
              tooltip: 'Open menu',
              color: const Color(0xFF16213E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: const Color(0xFF2A2A4E).withOpacity(0.7),
                ),
              ),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2A2A4E).withOpacity(0.5),
                  ),
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
                  size: 18,
                  color: Color(0xFF8899AA),
                ),
              ),
              onSelected: (value) {
                if (value == 'oil_monitor') {
                  _openOilMonitor();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  enabled: false,
                  value: 'subscription',
                  child: Row(
                    children: [
                      Icon(Icons.subscriptions_rounded, size: 18, color: Colors.white70),
                      SizedBox(width: 10),
                      Text('訂閱管理', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'oil_monitor',
                  child: Row(
                    children: [
                      Icon(Icons.oil_barrel_rounded, size: 18, color: Color(0xFF80DEEA)),
                      SizedBox(width: 10),
                      Text('石油監控'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : _subscriptions.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadSubscriptions,
                  color: const Color(0xFF7C4DFF),
                  backgroundColor: const Color(0xFF1A1A2E),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(child: _buildSummaryHeader()),
                      SliverToBoxAdapter(child: _buildExpiringBanner()),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 18,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '所有訂閱',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFCCDDEE),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF7C4DFF).withOpacity(0.15),
                                      const Color(0xFF7C4DFF).withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF7C4DFF).withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.sort_rounded, size: 12,
                                        color: const Color(0xFF7C4DFF).withOpacity(0.7)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '按日期排序（近→遠）',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: const Color(0xFF7C4DFF).withOpacity(0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 90),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = _subscriptions[index];
                              return SubscriptionCard(
                                item: item,
                                index: index,
                                onEdit: () => _showEditDialog(item),
                                onDelete: () => _deleteSubscription(item.id),
                              );
                            },
                            childCount: _subscriptions.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C4DFF).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFF448AFF).withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () => _showEditDialog(null),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add_rounded, size: 30, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
