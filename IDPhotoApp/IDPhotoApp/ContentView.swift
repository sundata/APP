import SwiftUI

struct ContentView: View {
    var body: some View {
        HomeView()
            .onAppear {
                print("✅ ContentView.onAppear - HomeView is loading...")
            }
    }
}

#Preview {
    ContentView()
}
