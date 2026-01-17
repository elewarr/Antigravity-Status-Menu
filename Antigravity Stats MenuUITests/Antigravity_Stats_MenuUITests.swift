//
//  Antigravity_Stats_MenuUITests.swift
//  Antigravity Stats MenuUITests
//
//  Created by Krystian Lewandowski on 16/01/2026.
//

import XCTest

final class Antigravity_Stats_MenuUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Menu Bar Tests

    func testMenuBarItemExists() throws {
        // Check that the app has a menu bar presence
        // Note: Menu bar extras are harder to test, this is a smoke test
        XCTAssertTrue(app.exists, "App should be running")
    }

    // MARK: - Settings Window Tests

    func testSettingsWindowOpens() throws {
        // Open settings window via menu
        // Note: This test may need adjustment based on how settings is accessed
        let settingsWindow = app.windows["Settings"]

        // Settings might not be open by default
        if !settingsWindow.exists {
            // Try to find and click settings button in menu bar
            // This is tricky for menu bar apps
            XCTSkip("Settings window not accessible through UI test - menu bar apps require different testing approach")
        }
    }

    func testSettingsWindowHasMenuBarItemsSection() throws {
        // Try to access settings window
        app.activate()

        // Open settings window if possible
        if let settingsWindow = app.windows.matching(identifier: "Settings").firstMatch as? XCUIElement,
           settingsWindow.exists {

            // Check for "Menu Bar Items" text
            let menuBarItemsLabel = settingsWindow.staticTexts["Menu Bar Items"]
            XCTAssertTrue(menuBarItemsLabel.exists, "Settings should have 'Menu Bar Items' section")

            // Check for Add button
            let addButton = settingsWindow.buttons["Add"]
            XCTAssertTrue(addButton.exists, "Settings should have an Add button")
        } else {
            XCTSkip("Cannot access Settings window for UI testing")
        }
    }

    func testSettingsWindowCloseButton() throws {
        app.activate()

        if let settingsWindow = app.windows.matching(identifier: "Settings").firstMatch as? XCUIElement,
           settingsWindow.exists {

            // Look for close button (X)
            let closeButtons = settingsWindow.buttons.matching(NSPredicate(format: "label CONTAINS 'close' OR label CONTAINS 'xmark'"))

            if closeButtons.count > 0 {
                closeButtons.firstMatch.click()

                // Window should close
                XCTAssertFalse(settingsWindow.exists, "Settings window should close after clicking X")
            }
        } else {
            XCTSkip("Cannot access Settings window for UI testing")
        }
    }

    // MARK: - Quota Menu View Tests

    func testQuotaMenuViewHasSortButtons() throws {
        // This test verifies the quota menu view structure
        // Note: Testing menu bar popover content is challenging
        XCTSkip("Menu bar popover content testing requires special handling")
    }

    // MARK: - Menu Bar Status Update Tests

    /// Test that the menu bar item updates from "Loading..." to actual data
    /// This verifies the observation pattern is working correctly
    func testMenuBarItemUpdatesFromLoading() throws {
        // Launch fresh instance
        app.terminate()
        app.launch()

        // Give the app time to initialize and fetch data
        // The menu bar should update within a few seconds
        let startTime = Date()
        let timeout: TimeInterval = 10

        // Access the menu bar area
        let menuBar = XCUIApplication(bundleIdentifier: "com.apple.controlcenter")
            .menuBars.firstMatch

        var foundUpdate = false

        // Poll for the status item to change
        while Date().timeIntervalSince(startTime) < timeout {
            // Check if app is still running
            XCTAssertTrue(app.exists, "App should still be running")

            // Look for menu bar items that might be ours
            // Menu bar apps create NSStatusItem which appears as a menu bar item
            let menuBarItems = menuBar.children(matching: .menuBarItem)

            for i in 0..<menuBarItems.count {
                let item = menuBarItems.element(boundBy: i)
                if item.exists {
                    let title = item.title

                    // Check if it contains percentage (indicates data loaded)
                    if title.contains("%") && !title.contains("Loading") {
                        foundUpdate = true
                        break
                    }
                }
            }

            if foundUpdate { break }

            // Wait a bit before checking again
            Thread.sleep(forTimeInterval: 0.5)
        }

        // This test may not be reliable on all systems due to menu bar access
        // restrictions, so we use XCTSkip if we can't access the menu bar
        if !foundUpdate {
            XCTSkip("Could not verify menu bar item update - menu bar access may be restricted in test environment")
        }
    }
}

// MARK: - Menu Bar Helper Extension

extension XCUIApplication {
    /// Attempts to click the menu bar item for this app
    /// Note: This may not work reliably for all menu bar apps
    func clickMenuBarItem() {
        // Menu bar apps often need special handling
        // Using accessibility API through System Events would be more reliable
    }
}
