import SwiftUI
import SwiftData

@main
struct CentreApp: App {
    @UIApplicationDelegateAdaptor(CentreAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    do {
                        _ = try await CardDiscoveryNotifications
                            .requestPermission()
                    } catch {
                        print(
                            "Notification permission request failed: "
                            + error.localizedDescription
                        )
                    }
                }
        }
        .modelContainer(CentreDataStore.container)
    }
}
