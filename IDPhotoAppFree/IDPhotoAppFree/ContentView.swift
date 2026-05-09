import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var adManager: AdManager

    var body: some View {
        HomeView()
            .onAppear {
                print("✅ ContentView.onAppear - HomeView is loading...")
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(AdManager())
}
