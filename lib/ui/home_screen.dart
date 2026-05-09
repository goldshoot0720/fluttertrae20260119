import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../data/model/subscription_item.dart';
import '../data/model/feng_bro_tube_models.dart';
import '../data/service/appwrite_service.dart';
import '../data/service/feng_bro_tube_service.dart';
import 'absurd_marriage_reason_screen.dart';
import 'battery_screen.dart';
import 'drunken_shrimp_marriage_reason_screen.dart';
import 'feng_bro_tube_screen.dart';
import 'feng_bro_tools_screen.dart';
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
  static const _sleepPromptDateKey = 'sleep_prompt_date';
  static const _sleepPromptCountKey = 'sleep_prompt_count';
  static const _sleepPromptLastAtKey = 'sleep_prompt_last_at';
  static const _codeLineCount = 12231;

  final AppwriteService _appwriteService = AppwriteService();
  final FengBroTubeService _tubeService = FengBroTubeService();
  List<SubscriptionItem> _subscriptions = [];
  FengBroTubeSummary? _tubeSummary;
  bool _isLoading = true;
  bool _bannerDismissed = false;
  bool _tubeBannerDismissed = false;
  late final AnimationController _asciiController;
  Timer? _sleepPromptTimer;
  int _sleepPromptCount = 0;
  DateTime? _lastSleepPromptAt;
  String _sleepPromptMessage = '尚未提示';

  static const List<String> _taiwanBankKeywords = [
    '臺灣銀行',
    '台灣銀行',
    '土地銀行',
    '土銀',
    '合作金庫',
    '合庫',
    '第一銀行',
    '一銀',
    '華南銀行',
    '華銀',
    '彰化銀行',
    '彰銀',
    '上海商銀',
    '台北富邦',
    '富邦銀行',
    '國泰世華',
    '高雄銀行',
    '高銀',
    '兆豐銀行',
    '兆豐',
    '王道銀行',
    '台中銀行',
    '京城銀行',
    '瑞興銀行',
    '華泰銀行',
    '新光銀行',
    '陽信銀行',
    '板信銀行',
    '三信銀行',
    '聯邦銀行',
    '遠東商銀',
    '遠銀',
    '元大銀行',
    '永豐銀行',
    '玉山銀行',
    '凱基銀行',
    '台新銀行',
    '安泰銀行',
    '中國信託',
    '中信銀行',
    '將來銀行',
    '連線銀行',
    'line bank',
    '樂天銀行',
    '星展台灣',
  ];

  static const List<String> _electronicTicketKeywords = [
    '電子票證',
    '悠遊卡',
    '悠遊付',
    '一卡通',
    'icash',
    '愛金卡',
    '全支付',
    '全盈',
    '街口',
    '橘子支付',
    'line pay',
    'px pay',
    '歐付寶',
  ];

  @override
  void initState() {
    super.initState();
    _asciiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _initSleepPromptState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      _initSystemTray();
    }
    _loadSubscriptions();
    _loadTubeHighlights();
  }

  @override
  void dispose() {
    _asciiController.dispose();
    _sleepPromptTimer?.cancel();
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
      iconPath: Platform.isWindows
          ? r'assets\app_icon.ico'
          : 'assets/app_icon.png',
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
      _showErrorSnackBar('讀取訂閱資料失敗：$e');
    }
  }

  Future<void> _loadTubeHighlights() async {
    try {
      final summary = await _tubeService.fetchLatest();
      if (!mounted) return;
      setState(() {
        _tubeSummary = summary;
        _tubeBannerDismissed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _tubeSummary = null);
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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const USDebtScreen()));
  }

  Future<void> _openOilPrice() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OilPriceScreen()));
  }

  Future<void> _openAbsurdMarriageReason() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AbsurdMarriageReasonScreen()),
    );
  }

  Future<void> _openDrunkenShrimpMarriageReason() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DrunkenShrimpMarriageReasonScreen(),
      ),
    );
  }

  Future<void> _openFengBroTools() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FengBroToolsScreen()));
  }

  Future<void> _openFengBroTube() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FengBroTubeScreen()));
  }

  Future<void> _initSleepPromptState() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateFormat('yyyyMMdd').format(DateTime.now());
    final storedDate = prefs.getString(_sleepPromptDateKey);

    if (storedDate != todayKey) {
      await prefs.setString(_sleepPromptDateKey, todayKey);
      await prefs.setInt(_sleepPromptCountKey, 0);
      await prefs.remove(_sleepPromptLastAtKey);
    }

    _sleepPromptCount = prefs.getInt(_sleepPromptCountKey) ?? 0;
    final lastAtMillis = prefs.getInt(_sleepPromptLastAtKey);
    if (lastAtMillis != null) {
      _lastSleepPromptAt = DateTime.fromMillisecondsSinceEpoch(lastAtMillis);
      _sleepPromptMessage = _formatPromptMessage(
        _lastSleepPromptAt!,
        _sleepPromptCount,
      );
    }

    _sleepPromptTimer ??= Timer.periodic(const Duration(seconds: 20), (
      _,
    ) async {
      await _checkSleepPrompt();
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _checkSleepPrompt() async {
    final now = DateTime.now();
    if (now.hour < 0 || now.hour > 4) {
      return;
    }

    final currentMinutes = now.hour * 60 + now.minute;
    final schedule = _sleepPromptMinutes();
    if (!schedule.contains(currentMinutes)) {
      return;
    }

    if (_lastSleepPromptAt != null) {
      final last = _lastSleepPromptAt!;
      if (last.year == now.year &&
          last.month == now.month &&
          last.day == now.day &&
          last.hour == now.hour &&
          last.minute == now.minute) {
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    _sleepPromptCount += 1;
    _lastSleepPromptAt = now;
    _sleepPromptMessage = _formatPromptMessage(now, _sleepPromptCount);
    await prefs.setInt(_sleepPromptCountKey, _sleepPromptCount);
    await prefs.setInt(_sleepPromptLastAtKey, now.millisecondsSinceEpoch);

    if (!mounted) return;
    setState(() {});
    _showSleepSnackBar(_sleepPromptMessage);
  }

  void _showSleepSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2A1F35),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatPromptMessage(DateTime time, int count) {
    final label = DateFormat('yyyy/MM/dd HH:mm').format(time);
    return '睡眠提示 $label 第$count次';
  }

  Set<int> _sleepPromptMinutes() {
    final minutes = <int>{};
    for (var hour = 0; hour < 2; hour++) {
      minutes.add(hour * 60);
      minutes.add(hour * 60 + 30);
    }
    for (var m = 120; m <= 240; m += 15) {
      minutes.add(m);
    }
    return minutes;
  }

  String _nextSleepPromptLabel() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final schedule = _sleepPromptMinutes().toList()..sort();

    for (final m in schedule) {
      if (m >= currentMinutes) {
        final h = m ~/ 60;
        final min = m % 60;
        final time = DateTime(now.year, now.month, now.day, h, min);
        return DateFormat('HH:mm').format(time);
      }
    }
    return '已結束';
  }

  _SleepWarningStyle? _currentSleepWarningStyle() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour <= 2) {
      return const _SleepWarningStyle(
        backgroundColor: Color(0xFFFFF3C4),
        borderColor: Color(0xFFF59E0B),
        iconColor: Color(0xFFD97706),
        titleColor: Color(0xFF7C2D12),
        messageColor: Color(0xFF92400E),
        label: '黃色警告',
      );
    }
    if (hour >= 3 && hour <= 6) {
      return const _SleepWarningStyle(
        backgroundColor: Color(0xFFFFDAD6),
        borderColor: Color(0xFFEF4444),
        iconColor: Color(0xFFDC2626),
        titleColor: Color(0xFF7F1D1D),
        messageColor: Color(0xFF991B1B),
        label: '紅色警告',
      );
    }
    return null;
  }

  Future<void> _openBattery() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BatteryScreen()));
  }

  List<SubscriptionItem> _getExpiringItems() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _subscriptions.where((item) {
      final itemDate = DateTime(
        item.nextDate.year,
        item.nextDate.month,
        item.nextDate.day,
      );
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

  int get _bankAccountCount {
    return _subscriptions.where(_isTaiwanBankAccount).length;
  }

  int get _electronicTicketCount {
    return _subscriptions.where((item) {
      final text = _bankClassificationText(item);
      return _isElectronicTicket(text) && !_isTaiwanBankAccount(item);
    }).length;
  }

  bool _isTaiwanBankAccount(SubscriptionItem item) {
    final text = _bankClassificationText(item).toLowerCase();
    return _taiwanBankKeywords.any(
      (keyword) => text.contains(keyword.toLowerCase()),
    );
  }

  String _bankClassificationText(SubscriptionItem item) {
    return '${item.name} ${item.account} ${item.note}'.trim();
  }

  bool _isElectronicTicket(String value) {
    final text = value.toLowerCase();
    return _electronicTicketKeywords.any(
      (keyword) => text.contains(keyword.toLowerCase()),
    );
  }

  Future<void> _showBankCategoryInfo() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('鋒兄銀行 (+電子票證)'),
        content: Text(
          '台灣的銀行才是銀行喔！銀行以外的先歸類為電子票證喔！\n\n'
          '銀行帳戶總數：$_bankAccountCount\n'
          '電子票證總數：$_electronicTicketCount',
          style: const TextStyle(color: Color(0xFFCDD6F4), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubscription(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('刪除訂閱'),
        content: const Text(
          '確定要刪除這筆訂閱嗎？此動作無法復原。',
          style: TextStyle(color: Color(0xFF8899AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('??'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
            ),
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

  void _showCreateDialogWithPreset(SubscriptionItem draft) {
    showDialog(
      context: context,
      builder: (context) => SubscriptionDialog(
        item: draft,
        isEditingOverride: false,
        onSave: (newItem) async {
          try {
            await _appwriteService.addSubscription(newItem);
            if (mounted) {
              Navigator.pop(context);
            }
            await _loadSubscriptions();
          } catch (e) {
            _showErrorSnackBar('新增訂閱失敗：$e');
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

  Widget _buildBankMenuButton() {
    return FilledButton.icon(
      onPressed: _showBankCategoryInfo,
      icon: const Icon(Icons.account_balance_wallet_rounded),
      label: const Text('鋒兄銀行 (+電子票證)'),
    );
  }

  Widget _buildSummarySection() {
    final expiringItems = _getExpiringItems();
    final sleepWarningStyle = _currentSleepWarningStyle();
    final tubeRecentVideos = _tubeSummary?.recentVideos() ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          if (sleepWarningStyle != null) ...[
            _buildSleepWarningBanner(sleepWarningStyle),
            const SizedBox(height: 14),
          ],
          if (tubeRecentVideos.isNotEmpty && !_tubeBannerDismissed) ...[
            _buildTubeNotificationBanner(tubeRecentVideos),
            const SizedBox(height: 14),
          ],
          _buildSleepPromptCard(),
          const SizedBox(height: 14),
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
                  '同步最新扣款與提醒，整理每月支出。',
                  style: TextStyle(color: Color(0xFF9AA7C2), fontSize: 14),
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
                      label: '即將扣款',
                      value: '${expiringItems.length}',
                      color: expiringItems.isEmpty
                          ? const Color(0xFF69F0AE)
                          : const Color(0xFFFF8A80),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatCard(
                      icon: Icons.account_balance_rounded,
                      label: '銀行帳戶總數',
                      value: '$_bankAccountCount',
                      color: const Color(0xFF69F0AE),
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      icon: Icons.credit_card_rounded,
                      label: '電子票證總數',
                      value: '$_electronicTicketCount',
                      color: const Color(0xFFFFD166),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '台灣的銀行才是銀行喔；銀行以外的先歸類為電子票證。',
                  style: TextStyle(color: Color(0xFF9AA7C2), fontSize: 12),
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
                      onPressed: _openDrunkenShrimpMarriageReason,
                      icon: const Icon(Icons.favorite_rounded),
                      label: const Text('醉蝦結婚理由'),
                    ),
                    FilledButton.icon(
                      onPressed: _openFengBroTools,
                      icon: const Icon(Icons.construction_rounded),
                      label: const Text('鋒兄工具'),
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
                    _buildBankMenuButton(),
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
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFF8A80),
                  ),
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
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFAA8891),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSleepWarningBanner(_SleepWarningStyle style) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: style.borderColor, width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.bedtime_rounded, color: style.iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style.label,
                  style: TextStyle(
                    color: style.titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '請入睡',
                  style: TextStyle(
                    color: style.messageColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTubeNotificationBanner(List<FengBroTubeVideo> videos) {
    final channelCount = videos
        .map((video) => video.channelName)
        .toSet()
        .length;
    final latest = videos.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.ondemand_video_rounded,
            color: Color(0xFFDC2626),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '鋒兄Tube 有 ${videos.length} 部 3 天內新影片',
                  style: const TextStyle(
                    color: Color(0xFF7C2D12),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$channelCount 個頻道更新，最新：${latest.channelName} - ${latest.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _openFengBroTube,
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      label: const Text('查看鋒兄Tube'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _tubeBannerDismissed = true),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('稍後提醒'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepPromptCard() {
    final nextLabel = _nextSleepPromptLabel();
    final today = DateFormat('yyyy/MM/dd').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2F3552)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '首頁睡眠提示',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '今日日期：$today',
            style: const TextStyle(color: Color(0xFF9AA7C2), fontSize: 13),
          ),
          const SizedBox(height: 12),
          _buildSleepRow('提示訊息', _sleepPromptMessage),
          _buildSleepRow('提示次數', '$_sleepPromptCount 次'),
          _buildSleepRow('下一次提示', nextLabel),
        ],
      ),
    );
  }

  Widget _buildSleepRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9AA7C2),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
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
                colors: [
                  Color(0xFF0B1023),
                  Color(0xFF111936),
                  Color(0xFF0C152B),
                ],
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                          color: const Color(
                            0xFF5DFFD1,
                          ).withOpacity(0.55 + glow),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
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
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                final draft = SubscriptionItem(
                  id: '',
                  name: '憌',
                  site: '',
                  price: 0,
                  nextDate: DateTime.now(),
                  note: '備註/提醒',
                  account: '',
                );
                _showCreateDialogWithPreset(draft);
              },
              icon: const Icon(Icons.restaurant_rounded),
              label: const Text('新增訂閱'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeLineFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Center(
        child: Text(
          '程式碼行數：$_codeLineCount 行',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
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
                        _buildCodeLineFooter(),
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
                                '點擊卡片查看或編輯訂閱內容。',
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
                        const SizedBox(height: 60),
                        _buildCodeLineFooter(),
                        const SizedBox(height: 20),
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

class _SleepWarningStyle {
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color titleColor;
  final Color messageColor;
  final String label;

  const _SleepWarningStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.titleColor,
    required this.messageColor,
    required this.label,
  });
}
