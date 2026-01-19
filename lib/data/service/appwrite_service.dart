import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import '../model/subscription_item.dart';

class AppwriteService {
  static const String endpoint = 'https://fra.cloud.appwrite.io/v1';
  static const String projectId = '680c76af0037a7d23e44';
  static const String databaseId = '680c778b000f055f6409';
  static const String subscriptionCollectionId = '687250d70020221fb26c';

  late Client client;
  late Databases databases;

  AppwriteService() {
    client = Client()
        .setEndpoint(endpoint)
        .setProject(projectId);
    databases = Databases(client);
  }

  Future<List<SubscriptionItem>> getSubscriptions() async {
    try {
      final documentList = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: subscriptionCollectionId,
        queries: [
          Query.orderAsc('nextdate'),
        ],
      );
      return documentList.documents
          .map((doc) => SubscriptionItem.fromJson(doc.data))
          .toList();
    } catch (e) {
      print('Error getting subscriptions: $e');
      rethrow;
    }
  }

  Future<void> addSubscription(SubscriptionItem item) async {
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
