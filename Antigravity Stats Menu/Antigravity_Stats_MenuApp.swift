//
//  Antigravity_Stats_MenuApp.swift
//  Antigravity Stats Menu
//
//  Created by Krystian Lewandowski on 16/01/2026.
//

import SwiftUI

/// Shared view model instance for app-wide access
@MainActor
let sharedViewModel = QuotaViewModel()

@main
struct Antigravity_Stats_MenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // ViewModel is initialized immediately via sharedViewModel
    }

    var body: some Scene {
        // Use Settings scene - the only SwiftUI scene needed
        Settings {
            SettingsView(availableModels: sharedViewModel.quotas)
        }
    }
}

/// Singleton manager for StatusBarController
@MainActor
final class StatusBarManager {
    static let shared = StatusBarManager()
    private var controller: StatusBarController?

    private init() {}

    func initialize(viewModel: QuotaViewModel) -> StatusBarController {
        if controller == nil {
            controller = StatusBarController(viewModel: viewModel)
        }
        return controller!
    }
}

/// AppDelegate to initialize StatusBarController and prevent Settings auto-opening
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable window state restoration to prevent Settings from auto-opening
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        // Close any windows that may have been restored (Settings, etc.) immediately
        DispatchQueue.main.async {
            for window in NSApp.windows {
                // Close any regular titled windows - menu bar extras are not regular windows
                if window.level == .normal && window.styleMask.contains(.titled) {
                    window.close()
                }
            }
        }

        // Initialize StatusBarController with shared view model
        Task { @MainActor in
            sharedViewModel.startAutoRefresh()
            _ = StatusBarManager.shared.initialize(viewModel: sharedViewModel)
        }
    }

    // Prevent window restoration
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
}
