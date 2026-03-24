import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../data/model/subscription_item.dart';
import '../data/service/appwrite_service.dart';
import 'oil_monitor_screen.dart';
import 'widgets/subscription_card.dart';
import 'widgets/subscription_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  final AppwriteService _appwriteService = AppwriteService();

  List<SubscriptionItem> _subscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      _initSystemTray();
    }
    _loadSubscriptions();
  }

  @override
  void dispose() {
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
      title: "Subscription Manager",
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
      final items = await _appwriteService.getSubscriptions();
      if (!mounted) return;
      setState(() {
        _subscriptions = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('載入訂閱資料失敗：$e', isError: true);
    }
  }

  Future<void> _openOilMonitor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OilMonitorScreen()),
    );
  }

  Future<void> _deleteSubscription(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除訂閱項目'),
        content: Text('確定要刪除「$name」嗎？這筆資料會從清單中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _appwriteService.deleteSubscription(id);
      await _loadSubscriptions();
    } catch (e) {
      _showMessage('刪除失敗：$e', isError: true);
    }
  }

  void _showEditDialog(SubscriptionItem? item) {
    showDialog<void>(
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
            if (!mounted) return;
            Navigator.pop(context);
            await _loadSubscriptions();
            _showMessage(item == null ? '訂閱項目已新增' : '訂閱項目已更新');
          } catch (e) {
            _showMessage(item == null ? '新增失敗：$e' : '更新失敗：$e', isError: true);
          }
        },
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            isError ? const Color(0xFF7A1F1A) : const Color(0xFF23423E),
        content: Text(message),
      ),
    );
  }

  List<SubscriptionItem> get _expiringItems {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = _subscriptions.where((item) {
      final next = DateTime(
        item.nextDate.year,
        item.nextDate.month,
        item.nextDate.day,
      );
      final diff = next.difference(today).inDays;
      return diff >= 0 && diff <= 3;
    }).toList();
    items.sort((a, b) => a.nextDate.compareTo(b.nextDate));
    return items;
  }

  int get _monthlyTotal =>
      _subscriptions.fold<int>(0, (sum, item) => sum + item.price);

  int get _activeAccounts =>
      _subscriptions.where((item) => item.account.trim().isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增訂閱'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF4EFE5),
              Color(0xFFEFE5D4),
              Color(0xFFF5F0E8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadSubscriptions,
            color: const Color(0xFF0F766E),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final horizontal = wide ? 32.0 : 20.0;

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          24,
                          horizontal,
                          16,
                        ),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: _buildHero(theme, compact: false),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    flex: 4,
                                    child: _buildSidePanel(theme),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildHero(theme, compact: true),
                                  const SizedBox(height: 16),
                                  _buildSidePanel(theme),
                                ],
                              ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontal),
                        child: _buildSectionHeader(theme),
                      ),
                    ),
                    if (_isLoading)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 120),
                          child: const _LoadingList(),
                        ),
                      )
                    else if (_subscriptions.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 120),
                          child: _buildEmptyState(theme),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 120),
                        sliver: SliverList.builder(
                          itemCount: _subscriptions.length,
                          itemBuilder: (context, index) {
                            final item = _subscriptions[index];
                            return SubscriptionCard(
                              item: item,
                              index: index,
                              onEdit: () => _showEditDialog(item),
                              onDelete: () => _deleteSubscription(item.id, item.name),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(ThemeData theme, {required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 22 : 28),
      decoration: BoxDecoration(
        color: const Color(0xFF16332F),
        borderRadius: BorderRadius.circular(36),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription\nCommand Deck',
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: const Color(0xFFF7F2E9),
                        height: 0.98,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '把週期性付款、提醒與帳號資訊整理成一個乾淨可行動的工作台。',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFD4DFDA),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: const Color(0xFF234B46),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.auto_awesome_mosaic_rounded,
                  color: Color(0xFFF8E7B3),
                  size: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatPanel(
                label: '活躍訂閱',
                value: '${_subscriptions.length}',
                tone: const Color(0xFF78D3C8),
              ),
              _StatPanel(
                label: '月支出',
                value: '\$$_monthlyTotal',
                tone: const Color(0xFFF4C970),
              ),
              _StatPanel(
                label: '近期扣款',
                value: '${_expiringItems.length}',
                tone: const Color(0xFFF09A7E),
              ),
              _StatPanel(
                label: '有帳號標記',
                value: '$_activeAccounts',
                tone: const Color(0xFFAAC5FF),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: _openOilMonitor,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE7D5A1),
                  foregroundColor: const Color(0xFF2F2413),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.oil_barrel_rounded),
                label: const Text('查看油價監控'),
              ),
              OutlinedButton.icon(
                onPressed: _loadSubscriptions,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF5F0E8),
                  side: const BorderSide(color: Color(0xFF4B6C67)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新整理'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(ThemeData theme) {
    return Column(
      children: [
        _buildExpiringPanel(theme),
        const SizedBox(height: 16),
        _buildInsightPanel(theme),
      ],
    );
  }

  Widget _buildExpiringPanel(ThemeData theme) {
    final items = _expiringItems;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EC),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD9CFBF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '近期提醒',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            items.isEmpty ? '接下來三天沒有即將扣款的項目。' : '優先處理未來三天內的扣款項目。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EFE6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('目前節奏穩定，暫時沒有急迫項目。'),
            )
          else
            ...items.map((item) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final diff = DateTime(
                item.nextDate.year,
                item.nextDate.month,
                item.nextDate.day,
              ).difference(today).inDays;
              final label = diff == 0 ? '今天' : diff == 1 ? '明天' : '$diff 天後';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE8D8C4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFB45309),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${DateFormat('MM/dd').format(item.nextDate)} · $label · \$${item.price}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildInsightPanel(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFEEE3CD),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '管理建議',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          const _InsightRow(
            title: '完整記錄帳號',
            body: '把共用帳號或付款帳號寫進欄位，之後查找與交接會快很多。',
          ),
          const SizedBox(height: 12),
          const _InsightRow(
            title: '網站連結可直接操作',
            body: '每筆訂閱放上服務網址後，檢查方案或取消服務時會更順手。',
          ),
          const SizedBox(height: 12),
          const _InsightRow(
            title: '把高頻支出排前面',
            body: '近期扣款項目會自然浮出，方便你先處理最需要決策的服務。',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Subscriptions',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E1B18),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '清單以可讀性和動作優先，讓你快速查看、修改與清理。',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EC),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFD9CFBF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '從第一筆訂閱開始建立',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '新增你常用的串流、雲端或工具服務，之後這裡就會變成你的續費儀表板。',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showEditDialog(null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('建立第一筆訂閱'),
          ),
        ],
      ),
    );
  }
}

class _StatPanel extends StatelessWidget {
  final String label;
  final String value;
  final Color tone;

  const _StatPanel({
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFC8D7D2),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String title;
  final String body;

  const _InsightRow({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            color: Color(0xFF0F766E),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(body),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFF9F5EC),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFD9CFBF)),
            ),
          ),
        ),
      ),
    );
  }
}
