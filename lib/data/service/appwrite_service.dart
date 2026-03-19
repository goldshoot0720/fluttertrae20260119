import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'appwrite_config.dart';
import '../model/subscription_item.dart';

class AppwriteService {
  static const String subscriptionCollectionName = 'subscription';

  late Client client;
  late Databases databases;
  final Completer<void> _initCompleter = Completer<void>();
  final Map<String, Future<String>> _collectionIdFutures = {};

  AppwriteService() {
    client = Client()
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId);
    databases = Databases(client);
    _waitAndOverrideUserAgent();
  }

  /// Wait until the SDK finishes initialization before overriding headers.
  Future<void> _waitAndOverrideUserAgent() async {
    while (!(client as dynamic).initialized) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    client.addHeader('user-agent', 'SubscriptionManager/1.0.0');
    _initCompleter.complete();
  }

  Future<void> _ensureInit() => _initCompleter.future;

  Future<String> _getSubscriptionCollectionId() {
    if (AppwriteConfig.subscriptionCollectionId.trim().isNotEmpty) {
      return Future.value(AppwriteConfig.subscriptionCollectionId);
    }
    return _getCollectionIdByName(subscriptionCollectionName);
  }

  Future<String> _getCollectionIdByName(String collectionName) {
    return _collectionIdFutures[collectionName] ??=
        _resolveCollectionIdByName(collectionName);
  }

  Future<String> _resolveCollectionIdByName(String collectionName) async {
    await _ensureInit();

    final httpClient = HttpClient();
    try {
      final uri = Uri.parse(
        '${AppwriteConfig.endpoint}/databases/${AppwriteConfig.databaseId}/collections',
      );
      final request = await httpClient.getUrl(uri);
      request.headers.set('X-Appwrite-Project', AppwriteConfig.projectId);
      request.headers.set('X-Appwrite-Response-Format', '1.8.0');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final responseData = jsonDecode(responseBody);
      final collections = responseData['collections'];

      if (collections is List) {
        for (final collection in collections) {
          if (collection is Map<String, dynamic> &&
              collection['name'] == collectionName) {
            final collectionId = collection[r'$id'];
            if (collectionId is String && collectionId.isNotEmpty) {
              return collectionId;
            }
          }
        }
      }
    } finally {
      httpClient.close(force: true);
    }

    throw Exception(
      'Collection "$collectionName" not found in database ${AppwriteConfig.databaseId}.',
    );
  }

  void _invalidateCollectionIdCache(String collectionName) {
    _collectionIdFutures.remove(collectionName);
  }

  Future<T> _withSubscriptionCollection<T>(
    Future<T> Function(String collectionId) action,
  ) async {
    try {
      final collectionId = await _getSubscriptionCollectionId();
      return await action(collectionId);
    } on AppwriteException catch (e) {
      final looksLikeCollectionIssue =
          e.code == 404 ||
          (e.message?.toLowerCase().contains('collection') ?? false);

      if (!looksLikeCollectionIssue) {
        rethrow;
      }

      _invalidateCollectionIdCache(subscriptionCollectionName);
      final refreshedCollectionId = await _getSubscriptionCollectionId();
      return action(refreshedCollectionId);
    }
  }

  Future<List<SubscriptionItem>> getSubscriptions() async {
    await _ensureInit();
    try {
      return await _withSubscriptionCollection((collectionId) async {
        final allSubscriptions = <SubscriptionItem>[];
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
            databaseId: AppwriteConfig.databaseId,
            collectionId: collectionId,
            queries: queries,
          );

          if (documentList.documents.isEmpty) {
            break;
          }

          allSubscriptions.addAll(
            documentList.documents.map(
              (doc) => SubscriptionItem.fromDocument(
                id: doc.$id,
                data: doc.data,
                createdAt: doc.$createdAt,
                updatedAt: doc.$updatedAt,
              ),
            ),
          );

          if (documentList.documents.length < 100) {
            break;
          }
          lastDocId = documentList.documents.last.$id;
        }

        allSubscriptions.sort((a, b) => a.nextDate.compareTo(b.nextDate));
        return allSubscriptions;
      });
    } catch (e) {
      print('Error getting subscriptions: $e');
      rethrow;
    }
  }

  Future<void> addSubscription(SubscriptionItem item) async {
    await _ensureInit();
    try {
      await _withSubscriptionCollection((collectionId) {
        return databases.createDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: collectionId,
          documentId: ID.unique(),
          data: item.toJson(),
        );
      });
    } catch (e) {
      print('Error adding subscription: $e');
      rethrow;
    }
  }

  Future<void> updateSubscription(SubscriptionItem item) async {
    await _ensureInit();
    if (item.id.trim().isEmpty) {
      throw ArgumentError(
        'Cannot update subscription without a document id.',
      );
    }
    try {
      await _withSubscriptionCollection((collectionId) {
        return databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: collectionId,
          documentId: item.id,
          data: item.toJson(),
        );
      });
    } catch (e) {
      print('Error updating subscription: $e');
      rethrow;
    }
  }

  Future<void> deleteSubscription(String id) async {
    await _ensureInit();
    if (id.trim().isEmpty) {
      throw ArgumentError(
        'Cannot delete subscription without a document id.',
      );
    }
    try {
      await _withSubscriptionCollection((collectionId) {
        return databases.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: collectionId,
          documentId: id,
        );
      });
    } catch (e) {
      print('Error deleting subscription: $e');
      rethrow;
    }
  }
}
