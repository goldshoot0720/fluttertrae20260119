import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import '../data/model/subscription_item.dart';
import '../data/service/appwrite_service.dart';
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

  @override
  void initState() {
    super.initState();
    _bannerAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bannerAnimation = CurvedAnimation(
      parent: _bannerAnimController,
      curve: Curves.easeOutBack,
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
      iconPath: 'assets/app_icon.ico',
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
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading subscriptions: $e')),
        );
      }
    }
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
    await _appwriteService.deleteSubscription(id);
    _loadSubscriptions();
  }

  void _showEditDialog(SubscriptionItem? item) {
    showDialog(
      context: context,
      builder: (context) => SubscriptionDialog(
        item: item,
        onSave: (newItem) async {
          if (item == null) {
            await _appwriteService.addSubscription(newItem);
          } else {
            newItem.id = item.id;
            await _appwriteService.updateSubscription(newItem);
          }
          _loadSubscriptions();
          Navigator.pop(context);
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
          colors: [Color(0xFF1A1A3E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A4E), width: 1),
      ),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.subscriptions_rounded,
            label: '訂閱總數',
            value: '${_subscriptions.length}',
            color: const Color(0xFF7C4DFF),
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            icon: Icons.payments_rounded,
            label: '總費用',
            value: '\$${_totalMonthlyCost}',
            color: const Color(0xFF00E5FF),
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            icon: Icons.warning_amber_rounded,
            label: '即將到期',
            value: '${_getExpiringItems().length}',
            color: _getExpiringItems().isNotEmpty
                ? const Color(0xFFFF5252)
                : const Color(0xFF4CAF50),
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
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8899AA),
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
            colors: [Color(0xFF4A1A1A), Color(0xFF2A1A3E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.4), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFFF5252), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '⚠️ ${expiringItems.length} 個訂閱即將到期',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFFF8A80),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF8899AA)),
                    onPressed: () {
                      setState(() => _bannerDismissed = true);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            ...expiringItems.map((item) {
              final itemDate = DateTime(item.nextDate.year, item.nextDate.month, item.nextDate.day);
              final daysLeft = itemDate.difference(today).inDays;
              final daysText = daysLeft == 0
                  ? '今天到期'
                  : daysLeft == 1
                      ? '明天到期'
                      : '$daysLeft 天後到期';
              final dateStr = '${item.nextDate.year}/${item.nextDate.month.toString().padLeft(2, '0')}/${item.nextDate.day.toString().padLeft(2, '0')}';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 32,
                      decoration: BoxDecoration(
                        color: daysLeft == 0
                            ? const Color(0xFFFF5252)
                            : daysLeft == 1
                                ? const Color(0xFFFF9800)
                                : const Color(0xFFFFEB3B),
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
                        color: daysLeft == 0
                            ? const Color(0xFFFF5252).withOpacity(0.3)
                            : daysLeft == 1
                                ? const Color(0xFFFF9800).withOpacity(0.3)
                                : const Color(0xFFFFEB3B).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        daysText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: daysLeft == 0
                              ? const Color(0xFFFF5252)
                              : daysLeft == 1
                                  ? const Color(0xFFFF9800)
                                  : const Color(0xFFFFEB3B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8899AA),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$${item.price}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F23),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.subscriptions_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Subscription Manager',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.list_alt, size: 16, color: Color(0xFF7C4DFF)),
                const SizedBox(width: 4),
                Text(
                  '${_subscriptions.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7C4DFF),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh_rounded, size: 20),
            ),
            onPressed: _loadSubscriptions,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      color: Color(0xFF7C4DFF),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '載入訂閱資料中...',
                    style: TextStyle(color: Color(0xFF8899AA), fontSize: 14),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSubscriptions,
              color: const Color(0xFF7C4DFF),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildSummaryHeader()),
                  SliverToBoxAdapter(child: _buildExpiringBanner()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Row(
                        children: [
                          const Text(
                            '所有訂閱',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFCCDDEE),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C4DFF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '按日期排序',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF7C4DFF).withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _subscriptions[index];
                          return SubscriptionCard(
                            item: item,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(null),
        elevation: 8,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C4DFF).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }
}
