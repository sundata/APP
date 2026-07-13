import SwiftUI

@main
struct WarimemoApp: App {
    @StateObject var groupManager = GroupManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(groupManager)
        }
    }
}
