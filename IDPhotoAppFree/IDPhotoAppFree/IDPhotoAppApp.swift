import SwiftUI
import GoogleMobileAds

@main
struct IDPhotoAppFreeApp: App {

    @StateObject private var adManager = AdManager()

    init() {
        print("🚀 IDPhotoAppApp init - App is starting...")
        // AdMob SDK 初期化
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(adManager)
                .onAppear {
                    print("✅ ContentView appeared - Main UI is visible!")
                }
        }
    }
}
