import SwiftUI

@main
struct IDPhotoAppApp: App {

    init() {
        print("🚀 IDPhotoAppApp init - App is starting...")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    print("✅ ContentView appeared - Main UI is visible!")
                }
        }
    }
}
