//
//  AppSettings.swift
//  Antigravity Stats Menu
//
//  Created by Krystian Lewandowski on 17/01/2026.
//

import Foundation
import SwiftUI

/// Sort type (without direction)
enum SortType: String, CaseIterable {
    case name = "name"
    case usage = "usage"
    case resetTime = "resetTime"

    var icon: String {
        switch self {
        case .name: return "textformat"
        case .usage: return "chart.bar"
        case .resetTime: return "clock"
        }
    }
}

/// Sort order for the menu pane list
enum QuotaSortOrder: String, CaseIterable, Codable {
    case nameAsc = "nameAsc"
    case nameDesc = "nameDesc"
    case usageAsc = "usageAsc"
    case usageDesc = "usageDesc"
    case resetTimeAsc = "resetTimeAsc"
    case resetTimeDesc = "resetTimeDesc"

    var sortType: SortType {
        switch self {
        case .nameAsc, .nameDesc: return .name
        case .usageAsc, .usageDesc: return .usage
        case .resetTimeAsc, .resetTimeDesc: return .resetTime
        }
    }

    var isAscending: Bool {
        switch self {
        case .nameAsc, .usageAsc, .resetTimeAsc: return true
        case .nameDesc, .usageDesc, .resetTimeDesc: return false
        }
    }

    var toggled: QuotaSortOrder {
        switch self {
        case .nameAsc: return .nameDesc
        case .nameDesc: return .nameAsc
        case .usageAsc: return .usageDesc
        case .usageDesc: return .usageAsc
        case .resetTimeAsc: return .resetTimeDesc
        case .resetTimeDesc: return .resetTimeAsc
        }
    }

    static func ascending(for type: SortType) -> QuotaSortOrder {
        switch type {
        case .name: return .nameAsc
        case .usage: return .usageAsc
        case .resetTime: return .resetTimeAsc
        }
    }
}

/// Represents a menu bar item configuration
struct MenuBarItem: Codable, Identifiable, Equatable {
    var id: UUID
    var modelKey: String?  // nil = show lowest/overall
    var icon: String  // SF Symbol name for display

    var isOverall: Bool { modelKey == nil }

    /// Available icons for the picker
    static let availableIcons = [
        "bolt.fill", "sparkles", "brain", "cpu", "wand.and.stars",
        "cloud.fill", "terminal.fill", "circle.grid.3x3.fill",
        "star.fill", "flame.fill", "leaf.fill", "moon.fill",
        "sun.max.fill", "burst.fill", "atom", "testtube.2"
    ]

    init(id: UUID = UUID(), modelKey: String? = nil, icon: String = "bolt.fill") {
        self.id = id
        self.modelKey = modelKey
        self.icon = icon
    }
}

/// Persistent app settings using UserDefaults
@Observable
final class AppSettings {

    // MARK: - Singleton

    static let shared = AppSettings()

    // MARK: - Menu Bar Items

    /// List of menu bar items to display
    var menuBarItems: [MenuBarItem] {
        get {
            if let data = UserDefaults.standard.data(forKey: "menuBarItems"),
               let items = try? JSONDecoder().decode([MenuBarItem].self, from: data) {
                return items
            }
            // Default: one overall item
            return [MenuBarItem(modelKey: nil)]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "menuBarItems")
            }
        }
    }

    /// Add a new menu bar item for a specific model
    func addMenuBarItem(for modelKey: String?) {
        var items = menuBarItems
        items.append(MenuBarItem(modelKey: modelKey))
        menuBarItems = items
    }

    /// Remove a menu bar item by ID
    func removeMenuBarItem(id: UUID) {
        var items = menuBarItems
        items.removeAll { $0.id == id }
        // Ensure at least one item remains
        if items.isEmpty {
            items = [MenuBarItem(modelKey: nil)]
        }
        menuBarItems = items
    }

    /// Update the icon for a menu bar item
    func updateMenuBarItemIcon(id: UUID, icon: String) {
        var items = menuBarItems
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].icon = icon
            menuBarItems = items
        }
    }

    // MARK: - Sorting

    /// Sort order for the menu pane quota list
    var sortOrder: QuotaSortOrder {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: "sortOrder"),
               let order = QuotaSortOrder(rawValue: rawValue) {
                return order
            }
            return .usageAsc  // Default: lowest usage first
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "sortOrder")
        }
    }

    // MARK: - Initialization

    private init() {}
}
