import SwiftUI

@main
struct HAWK_ADMINApp: App {
    @StateObject private var appConfig = AppConfig()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appConfig)
                .task {
                    appConfig.setupAutoUpdates()
                    appConfig.appDidBecomeActive()
                }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        appConfig.appDidBecomeActive()
                    case .background:
                        appConfig.appDidEnterBackground()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}
