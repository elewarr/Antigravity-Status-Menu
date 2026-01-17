//
//  Antigravity_Stats_MenuTests.swift
//  Antigravity Stats MenuTests
//
//  Created by Krystian Lewandowski on 16/01/2026.
//

import XCTest
@testable import Antigravity_Stats_Menu

final class Antigravity_Stats_MenuTests: XCTestCase {

    override func setUpWithError() throws {
        // Clear UserDefaults before each test
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "menuBarItems")
        defaults.removeObject(forKey: "sortOrder")
    }

    override func tearDownWithError() throws {
        // Clean up
    }

    // MARK: - AppSettings Tests

    func testDefaultMenuBarItems() throws {
        let settings = AppSettings.shared
        let items = settings.menuBarItems

        XCTAssertEqual(items.count, 1, "Should have exactly one default item")
        XCTAssertNil(items.first?.modelKey, "Default item should be 'first sorted' (nil modelKey)")
    }

    func testAddMenuBarItem() throws {
        let settings = AppSettings.shared

        settings.addMenuBarItem(for: "claude-sonnet")

        let items = settings.menuBarItems
        XCTAssertEqual(items.count, 2, "Should have 2 items after adding")
        XCTAssertEqual(items.last?.modelKey, "claude-sonnet", "Last item should be the added model")
    }

    func testRemoveMenuBarItem() throws {
        let settings = AppSettings.shared

        // Add an item first
        settings.addMenuBarItem(for: "gemini-pro")
        XCTAssertEqual(settings.menuBarItems.count, 2)

        // Remove the original item
        let firstId = settings.menuBarItems.first!.id
        settings.removeMenuBarItem(id: firstId)

        XCTAssertEqual(settings.menuBarItems.count, 1)
        XCTAssertEqual(settings.menuBarItems.first?.modelKey, "gemini-pro")
    }

    func testCannotRemoveLastItem() throws {
        let settings = AppSettings.shared

        // Try to remove the only item
        let onlyItemId = settings.menuBarItems.first!.id
        settings.removeMenuBarItem(id: onlyItemId)

        // Should still have one item (reset to default)
        XCTAssertEqual(settings.menuBarItems.count, 1)
    }

    func testDefaultSortOrder() throws {
        let settings = AppSettings.shared

        XCTAssertEqual(settings.sortOrder, .usageAsc, "Default sort should be usage ascending")
    }

    func testSortOrderPersistence() throws {
        let settings = AppSettings.shared

        settings.sortOrder = .resetTimeDesc

        // Re-read from UserDefaults
        let storedRawValue = UserDefaults.standard.string(forKey: "sortOrder")
        XCTAssertEqual(storedRawValue, "resetTimeDesc")
    }

    // MARK: - QuotaSortOrder Tests

    func testSortOrderToggle() throws {
        XCTAssertEqual(QuotaSortOrder.nameAsc.toggled, .nameDesc)
        XCTAssertEqual(QuotaSortOrder.nameDesc.toggled, .nameAsc)
        XCTAssertEqual(QuotaSortOrder.usageAsc.toggled, .usageDesc)
        XCTAssertEqual(QuotaSortOrder.usageDesc.toggled, .usageAsc)
        XCTAssertEqual(QuotaSortOrder.resetTimeAsc.toggled, .resetTimeDesc)
        XCTAssertEqual(QuotaSortOrder.resetTimeDesc.toggled, .resetTimeAsc)
    }

    func testSortType() throws {
        XCTAssertEqual(QuotaSortOrder.nameAsc.sortType, .name)
        XCTAssertEqual(QuotaSortOrder.nameDesc.sortType, .name)
        XCTAssertEqual(QuotaSortOrder.usageAsc.sortType, .usage)
        XCTAssertEqual(QuotaSortOrder.usageDesc.sortType, .usage)
        XCTAssertEqual(QuotaSortOrder.resetTimeAsc.sortType, .resetTime)
        XCTAssertEqual(QuotaSortOrder.resetTimeDesc.sortType, .resetTime)
    }

    func testIsAscending() throws {
        XCTAssertTrue(QuotaSortOrder.nameAsc.isAscending)
        XCTAssertFalse(QuotaSortOrder.nameDesc.isAscending)
        XCTAssertTrue(QuotaSortOrder.usageAsc.isAscending)
        XCTAssertFalse(QuotaSortOrder.usageDesc.isAscending)
    }

    func testAscendingForType() throws {
        XCTAssertEqual(QuotaSortOrder.ascending(for: .name), .nameAsc)
        XCTAssertEqual(QuotaSortOrder.ascending(for: .usage), .usageAsc)
        XCTAssertEqual(QuotaSortOrder.ascending(for: .resetTime), .resetTimeAsc)
    }

    // MARK: - MenuBarItem Tests

    func testMenuBarItemEquality() throws {
        let id = UUID()
        let item1 = MenuBarItem(id: id, modelKey: "test")
        let item2 = MenuBarItem(id: id, modelKey: "test")

        XCTAssertEqual(item1, item2)
    }

    func testMenuBarItemIsOverall() throws {
        let overallItem = MenuBarItem(modelKey: nil)
        let specificItem = MenuBarItem(modelKey: "claude")

        XCTAssertTrue(overallItem.isOverall)
        XCTAssertFalse(specificItem.isOverall)
    }

    // MARK: - ModelQuota Tests

    func testModelQuotaPercentage() throws {
        let quota = ModelQuota(
            modelKey: "test",
            displayLabel: "Test Model",
            remainingFraction: 0.75,
            resetTime: nil,
            supportsImages: false,
            isNew: false
        )

        XCTAssertEqual(quota.remainingPercentage, 75.0)
    }

    func testModelQuotaShortName() throws {
        let quota = ModelQuota(
            modelKey: "test",
            displayLabel: "Claude Sonnet 4.5 (Thinking)",
            remainingFraction: 0.5,
            resetTime: nil,
            supportsImages: false,
            isNew: false
        )

        // Should remove "(Thinking)" and "Sonnet "
        XCTAssertFalse(quota.shortName.contains("(Thinking)"))
        XCTAssertFalse(quota.shortName.contains("Sonnet"))
    }

    func testModelQuotaStatusEmoji() throws {
        let highQuota = ModelQuota(modelKey: "h", displayLabel: "H", remainingFraction: 0.8, resetTime: nil, supportsImages: false, isNew: false)
        let mediumQuota = ModelQuota(modelKey: "m", displayLabel: "M", remainingFraction: 0.2, resetTime: nil, supportsImages: false, isNew: false)
        let lowQuota = ModelQuota(modelKey: "l", displayLabel: "L", remainingFraction: 0.05, resetTime: nil, supportsImages: false, isNew: false)

        XCTAssertEqual(highQuota.statusEmoji, "🟢")
        XCTAssertEqual(mediumQuota.statusEmoji, "🟡")
        XCTAssertEqual(lowQuota.statusEmoji, "🔴")
    }

    func testModelQuotaFormattedResetTime() throws {
        let futureQuota = ModelQuota(
            modelKey: "test",
            displayLabel: "Test",
            remainingFraction: 0.5,
            resetTime: Date().addingTimeInterval(3700), // 1h 1m
            supportsImages: false,
            isNew: false
        )

        let formatted = futureQuota.formattedResetTime
        XCTAssertTrue(formatted.contains("h"), "Should contain hours for >1h")
    }
}
