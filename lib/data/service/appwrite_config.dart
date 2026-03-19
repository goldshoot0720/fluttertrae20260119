class AppwriteConfig {
  static const String endpoint = String.fromEnvironment(
    'NEXT_PUBLIC_APPWRITE_ENDPOINT',
    defaultValue: 'https://sgp.cloud.appwrite.io/v1',
  );

  static const String projectId = String.fromEnvironment(
    'NEXT_PUBLIC_APPWRITE_PROJECT_ID',
    defaultValue: '698212e50017eada99c8',
  );

  static const String databaseId = String.fromEnvironment(
    'APPWRITE_DATABASE_ID',
    defaultValue: '69821743002139037da1',
  );

  static const String subscriptionCollectionId = String.fromEnvironment(
    'APPWRITE_SUBSCRIPTION_COLLECTION_ID',
    defaultValue: '6982182b002e6a6680b4',
  );

  static const String bucketId = String.fromEnvironment(
    'APPWRITE_BUCKET_ID',
    defaultValue: '698215640037d1a67e6b',
  );
}
