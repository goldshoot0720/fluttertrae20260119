import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import '../model/subscription_item.dart';

class AppwriteService {
  static const String endpoint = 'https://sgp.cloud.appwrite.io/v1';
  static const String projectId = '698212e50017eada99c8';
  static const String databaseId = '69821743002139037da1';
  static const String subscriptionCollectionId = '6982182b002e6a6680b4';

  late Client client;
  late Databases databases;
  final Completer<void> _initCompleter = Completer<void>();

  AppwriteService() {
    client = Client()
        .setEndpoint(endpoint)
        .setProject(projectId);
    databases = Databases(client);
    _waitAndOverrideUserAgent();
  }

  /// Appwrite SDK 的 init() 是非同步的，會在完成後用電腦名稱覆蓋 user-agent。
  /// 這裡等待 SDK init 完成後，再覆寫為純 ASCII 字串。
  Future<void> _waitAndOverrideUserAgent() async {
    while (!(client as dynamic).initialized) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    client.addHeader('user-agent', 'SubscriptionManager/1.0.0');
    _initCompleter.complete();
  }

  Future<void> _ensureInit() => _initCompleter.future;

  Future<List<SubscriptionItem>> getSubscriptions() async {
    await _ensureInit();
    try {
      List<SubscriptionItem> allSubscriptions = [];
      String? lastDocId;
      
      while (true) {
        final queries = <String>[
          Query.orderAsc('nextdate'),
          Query.limit(100),
        ];
        if (lastDocId != null) {
          queries.add(Query.cursorAfter(lastDocId));
        }
        
        final documentList = await databases.listDocuments(
          databaseId: databaseId,
          collectionId: subscriptionCollectionId,
          queries: queries,
        );
        
        if (documentList.documents.isEmpty) break;
        
        allSubscriptions.addAll(
          documentList.documents.map((doc) => SubscriptionItem.fromJson(doc.data)),
        );
        
        if (documentList.documents.length < 100) break;
        lastDocId = documentList.documents.last.$id;
      }
      
      // 客戶端排序：日期由近到遠，無日期（2099）排最後
      allSubscriptions.sort((a, b) => a.nextDate.compareTo(b.nextDate));
      return allSubscriptions;
    } catch (e) {
      print('Error getting subscriptions: $e');
      rethrow;
    }
  }

  Future<void> addSubscription(SubscriptionItem item) async {
    await _ensureInit();
    try {
      await databases.createDocument(
        databaseId: databaseId,
        collectionId: subscriptionCollectionId,
        documentId: ID.unique(),
        data: item.toJson(),
      );
    } catch (e) {
      print('Error adding subscription: $e');
      rethrow;
    }
  }

  Future<void> updateSubscription(SubscriptionItem item) async {
    await _ensureInit();
    try {
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: subscriptionCollectionId,
        documentId: item.id,
        data: item.toJson(),
      );
    } catch (e) {
      print('Error updating subscription: $e');
      rethrow;
    }
  }

  Future<void> deleteSubscription(String id) async {
    await _ensureInit();
    try {
      await databases.deleteDocument(
        databaseId: databaseId,
        collectionId: subscriptionCollectionId,
        documentId: id,
      );
    } catch (e) {
      print('Error deleting subscription: $e');
      rethrow;
    }
  }
}
