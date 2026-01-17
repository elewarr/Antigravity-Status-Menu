//
//  StatusBarController.swift
//  Antigravity Stats Menu
//
//  Created by Krystian Lewandowski on 17/01/2026.
//

import AppKit
import SwiftUI
import Combine

/// Manages multiple NSStatusItems for dynamic menu bar presence
@MainActor
final class StatusBarController {

    private var statusItems: [UUID: NSStatusItem] = [:]
    private var primaryStatusItem: NSStatusItem?  // Reference to primary item for popup trigger
    private var viewModel: QuotaViewModel
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private var popover: NSPopover?  // Popover for primary item click

    /// Cache the last known configuration to prevent unnecessary rebuilds
    private var lastKnownConfigHash: Int = 0
    private var isRebuilding: Bool = false

    init(viewModel: QuotaViewModel) {
        self.viewModel = viewModel

        // Create status items immediately
        setupStatusItems()

        // Observe settings changes - only rebuild if menu bar items actually changed
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.checkAndUpdateIfNeeded()
            }
            .store(in: &cancellables)

        // Observe view model changes reactively
        observeViewModel()

        // Update display periodically (as backup for time-based updates like countdowns)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.updateDisplay()
            }
        }

        // Initial update after a short delay to catch first data load
        // This is a workaround for observation sometimes missing the first update
        Task { @MainActor [weak self] in
            // Wait for initial data to likely be loaded
            try? await Task.sleep(for: .seconds(2))
            print("[StatusBar] Initial delayed update")
            self?.updateDisplay()
        }
    }

    /// Observe view model changes using Swift Observation framework
    private func observeViewModel() {
        // Use withObservationTracking to get notified when quotas change
        withObservationTracking {
            // Access the properties we care about to register for tracking
            _ = viewModel.quotas
            _ = viewModel.isConnected
            _ = viewModel.isLoading
            print("[StatusBar] Registered observation - quotas: \(viewModel.quotas.count), connected: \(viewModel.isConnected), loading: \(viewModel.isLoading)")
        } onChange: { [weak self] in
            print("[StatusBar] onChange triggered")
            // Defer to next runloop to avoid layout recursion
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    print("[StatusBar] self is nil in onChange")
                    return
                }
                print("[StatusBar] Calling updateDisplay from observation")
                self.updateDisplay()
                // Re-register for next change
                self.observeViewModel()
            }
        }
    }

    /// Only rebuild status items if the configuration actually changed
    private func checkAndUpdateIfNeeded() {
        // Prevent concurrent rebuilds
        guard !isRebuilding else { return }

        let currentItems = AppSettings.shared.menuBarItems

        // Create a stable hash of the configuration
        var hasher = Hasher()
        for item in currentItems {
            hasher.combine(item.id)
            hasher.combine(item.modelKey)
            hasher.combine(item.icon)
        }
        let configHash = hasher.finalize()

        // Only rebuild if the hash changed
        guard configHash != lastKnownConfigHash else {
            // Just update display, don't rebuild
            updateDisplay()
            return
        }

        lastKnownConfigHash = configHash
        setupStatusItems()
    }

    deinit {
        updateTimer?.invalidate()
    }

    /// Rebuild status items based on current settings
    func setupStatusItems() {
        // Prevent overlapping rebuilds
        guard !isRebuilding else { return }
        isRebuilding = true
        defer { isRebuilding = false }

        let settings = AppSettings.shared
        let allItems = settings.menuBarItems

        // Update the hash for direct calls
        var hasher = Hasher()
        for item in allItems {
            hasher.combine(item.id)
            hasher.combine(item.modelKey)
            hasher.combine(item.icon)
        }
        lastKnownConfigHash = hasher.finalize()

        // Remove items that no longer exist in settings
        let currentIDs = Set(allItems.map(\.id))
        for id in statusItems.keys where !currentIDs.contains(id) {
            if let item = statusItems[id] {
                NSStatusBar.system.removeStatusItem(item)
            }
            statusItems.removeValue(forKey: id)
        }

        // Add/update ALL items including primary
        for menuItem in allItems {
            if statusItems[menuItem.id] == nil {
                // Create with variable length for verbose display
                let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                statusItems[menuItem.id] = statusItem

                // Primary item (modelKey == nil) gets click handler to open popup
                if menuItem.modelKey == nil {
                    statusItem.button?.target = self
                    statusItem.button?.action = #selector(primaryItemClicked(_:))
                    statusItem.button?.sendAction(on: .leftMouseUp)
                    // Store reference for popup trigger
                    primaryStatusItem = statusItem
                }
            }

            updateStatusItemDisplay(id: menuItem.id, item: menuItem)
        }
    }

    /// Handle click on primary status item - toggles the popover
    @objc private func primaryItemClicked(_ sender: NSStatusBarButton) {
        // Toggle popover
        if let popover = popover, popover.isShown {
            popover.performClose(sender)
            return
        }

        // Create popover if needed
        if popover == nil {
            let newPopover = NSPopover()
            newPopover.behavior = .transient
            newPopover.animates = true
            newPopover.contentViewController = NSHostingController(rootView: QuotaMenuView(viewModel: viewModel))
            popover = newPopover
        }

        // Show popover relative to the button
        if let button = primaryStatusItem?.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// Update the display text for all status items
    func updateDisplay() {
        print("[StatusBar] updateDisplay called - quotas: \(viewModel.quotas.count)")
        let settings = AppSettings.shared
        for menuItem in settings.menuBarItems {
            updateStatusItemDisplay(id: menuItem.id, item: menuItem)
        }
    }

    private func updateStatusItemDisplay(id: UUID, item: MenuBarItem) {
        guard let statusItem = statusItems[id] else { return }
        guard let button = statusItem.button else { return }

        // Determine which quota to display
        let quota: ModelQuota?
        if let modelKey = item.modelKey {
            // Specific model
            quota = viewModel.quotas.first(where: { $0.modelKey == modelKey })
        } else {
            // Primary item - show first sorted model
            quota = viewModel.firstSortedModel
        }

        if let quota = quota {
            // Create icon-based display: icon + percentage + time
            // Format: "⚡ 75% │ 2h 15m"

            let percentText = "\(Int(quota.remainingPercentage))%"
            let timeText = quota.formattedResetTime

            // Build attributed string for styled display
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attributedString = NSMutableAttributedString()

            // Add icon as NSImage
            if let iconImage = NSImage(systemSymbolName: item.icon, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
                let configuredImage = iconImage.withSymbolConfiguration(config) ?? iconImage

                let imageAttachment = NSTextAttachment()
                imageAttachment.image = configuredImage
                attributedString.append(NSAttributedString(attachment: imageAttachment))
                attributedString.append(NSAttributedString(string: " "))
            }

            // Percentage - colored based on value
            let percentColor = colorForPercentage(quota.remainingPercentage)
            let percentAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: percentColor,
                .paragraphStyle: paragraphStyle
            ]
            attributedString.append(NSAttributedString(string: percentText, attributes: percentAttrs))

            // Separator
            let sepAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .light),
                .foregroundColor: NSColor.tertiaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
            attributedString.append(NSAttributedString(string: " │ ", attributes: sepAttrs))

            // Reset time
            let timeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
            attributedString.append(NSAttributedString(string: timeText, attributes: timeAttrs))

            button.attributedTitle = attributedString

            // Set icon from menu bar item configuration
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            button.image = NSImage(systemSymbolName: item.icon, accessibilityDescription: quota.displayLabel)?.withSymbolConfiguration(config)
            button.imagePosition = .imageLeft

        } else {
            // Model not found or loading
            let displayText = item.modelKey?.prefix(8).map(String.init).joined() ?? "Loading"
            button.title = displayText + "..."
            button.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: nil)
        }
    }



    private func colorForPercentage(_ percentage: Double) -> NSColor {
        if percentage > 50 {
            return NSColor.systemGreen
        } else if percentage > 20 {
            return NSColor.systemOrange
        } else {
            return NSColor.systemRed
        }
    }

    // Status items are display-only - no click handling
    // The main MenuBarExtra handles the popup interaction
}
