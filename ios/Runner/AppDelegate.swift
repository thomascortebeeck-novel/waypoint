import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Use env var for local runs (set in Xcode: Edit Scheme → Run → Environment Variables → GOOGLE_MAPS_API_KEY).
    // CI replaces YOUR_GOOGLE_MAPS_API_KEY with the real key via sed.
    let mapsKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"] ?? "YOUR_GOOGLE_MAPS_API_KEY"
    GMSServices.provideAPIKey(mapsKey)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
