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

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  final AppwriteService _appwriteService = AppwriteService();
  List<SubscriptionItem> _subscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initSystemTray();
    _loadSubscriptions();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    bool _isPreventClose = await windowManager.isPreventClose();
    if (_isPreventClose) {
      windowManager.hide();
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
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // In production, might want to show error only if not silent background update
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading subscriptions: $e')),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSubscriptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _subscriptions.length,
              itemBuilder: (context, index) {
                final item = _subscriptions[index];
                return SubscriptionCard(
                  item: item,
                  onEdit: () => _showEditDialog(item),
                  onDelete: () => _deleteSubscription(item.id),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
