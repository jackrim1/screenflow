import SwiftUI
import ScreenFlowCore

@main
struct ScreenFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // MenuBarExtra is the correct SwiftUI API for menu-bar-only apps on macOS 13+.
        // It replaces the old `Settings { EmptyView() }` workaround that was causing
        // an empty Settings window to appear on launch.
        MenuBarExtra {
            PopoverView(
                store: appDelegate.store,
                openGallery: { appDelegate.openGallery() }
            )
        } label: {
            Image(systemName: appDelegate.menuBarIconName)
        }
        .menuBarExtraStyle(.window)
    }
}
