# Subscription Manager

A Flutter application to manage subscriptions, featuring:

- **Appwrite Integration**: Syncs data with Appwrite backend.
- **Cross-Platform**: Supports Android and Windows.
- **Notifications**: 
  - Startup check.
  - Daily background check (Windows).
  - Notifications for subscriptions expiring in the next 3 days.
- **UI**: Clean interface with sorting and management features.

## Getting Started

1.  **Prerequisites**:
    -   Flutter SDK installed.
    -   Appwrite project set up with appropriate Database and Collection IDs.

2.  **Configuration**:
    -   Provide Appwrite settings with `--dart-define` when running the app.
    -   Supported keys:
        `NEXT_PUBLIC_APPWRITE_ENDPOINT`
        `NEXT_PUBLIC_APPWRITE_PROJECT_ID`
        `APPWRITE_DATABASE_ID`
        `APPWRITE_BUCKET_ID`
    -   Do not place `APPWRITE_API_KEY` in the Flutter client. Keep API keys on a server or Appwrite Function only.

3.  **Run**:
    ```bash
    flutter run \
      --dart-define=NEXT_PUBLIC_APPWRITE_ENDPOINT=https://sgp.cloud.appwrite.io/v1 \
      --dart-define=NEXT_PUBLIC_APPWRITE_PROJECT_ID=698212e50017eada99c8 \
      --dart-define=APPWRITE_DATABASE_ID=69821743002139037da1 \
      --dart-define=APPWRITE_BUCKET_ID=698215640037d1a67e6b
    ```
