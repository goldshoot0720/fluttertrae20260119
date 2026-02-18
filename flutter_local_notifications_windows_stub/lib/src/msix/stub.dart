import '../../flutter_local_notifications_windows.dart';

/// Helpful methods to support MSIX and package identity.
class MsixUtils {
  static bool hasPackageIdentity() => false; // platforms without FFI

  /// Gets an `ms-appx:///` URI from a Flutter asset.
  static Uri getAssetUri(String path) =>
      Uri.parse('ms-appx:///data/flutter_assets/$path');
}
