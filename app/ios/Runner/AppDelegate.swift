import UIKit
import Flutter
import Firebase
import GoogleSignIn
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    
    // Configure Google Maps
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String {
      GMSServices.provideAPIKey(apiKey)
    }
    
    // Configure Google Sign-In v7.x
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let plistData = NSDictionary(contentsOfFile: path),
       let clientId = plistData["CLIENT_ID"] as? String {
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
