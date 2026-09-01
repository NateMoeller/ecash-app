import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeDocumentsFromICloudBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// The wallet DB (`client.db`) and the plaintext log both live in Documents, which iOS
  /// backs up to iCloud by default. `client.db` holds the raw BIP39 entropy — it is not in
  /// the Keychain — so backing it up copies the seed off-device. Excluding the directory
  /// covers the whole subtree, including anything added to it later.
  ///
  /// Runs before the Flutter engine starts, so the flag is set before either artifact is
  /// created, and re-runs every launch so a lost flag heals itself.
  private func excludeDocumentsFromICloudBackup() {
    guard var documents = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    do {
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try documents.setResourceValues(values)
    } catch {
      // Never fatal: a hardening measure must not break the thing it protects.
      NSLog("[ecashapp] failed to exclude Documents from backup: \(error)")
    }
    // Read back so the QA pass can confirm from the device console.
    let excluded = (try? documents.resourceValues(forKeys: [.isExcludedFromBackupKey]))?
      .isExcludedFromBackup ?? false
    NSLog("[ecashapp] Documents excluded from iCloud backup: \(excluded)")
  }
}
