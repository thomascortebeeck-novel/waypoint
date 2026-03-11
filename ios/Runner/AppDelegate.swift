import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Use same key as web (index.html). Restrict in Google Cloud Console by bundle ID com.thomascortebeeck.waypoint.
    GMSServices.provideAPIKey("AIzaSyAbK1n5nk4DUKsWps05V8c4hv94b2vI-cA")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
