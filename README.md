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
    -   Update `lib/data/service/appwrite_service.dart` with your Appwrite endpoint and IDs.

3.  **Run**:
    ```bash
    flutter run
    ```
