import Flutter
import UIKit
import CoreLocation
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  var locationManager: CLLocationManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ✅ 1. Cookies persistentes a nivel de sistema
    HTTPCookieStorage.shared.cookieAcceptPolicy = .always

    // ✅ 2. WKWebsiteDataStore persistente (NO ephemeral)
    if #available(iOS 11.0, *) {
      let dataStore = WKWebsiteDataStore.default() // ← .default() es persistente
      let config = WKWebViewConfiguration()
      config.websiteDataStore = dataStore
      config.allowsInlineMediaPlayback = true
      config.mediaTypesRequiringUserActionForPlayback = []

      // ✅ 3. Fuerza que las cookies del sistema se sincronicen con WKWebView
      let cookies = HTTPCookieStorage.shared.cookies ?? []
      for cookie in cookies {
        dataStore.httpCookieStore.setCookie(cookie, completionHandler: nil)
      }
    }

    // ✅ 4. Localización
    locationManager = CLLocationManager()
    locationManager?.delegate = self
    locationManager?.requestWhenInUseAuthorization()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
