//
//  SettingsView.swift
//  Antigravity Stats Menu
//
//  Created by Krystian Lewandowski on 17/01/2026.
//

import SwiftUI

/// Settings window for configuring menu bar items
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let settings = AppSettings.shared
    let availableModels: [ModelQuota]

    @State private var menuBarItems: [MenuBarItem]

    init(availableModels: [ModelQuota]) {
        self.availableModels = availableModels
        _menuBarItems = State(initialValue: AppSettings.shared.menuBarItems)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with X button
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.blue)
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }

            Divider()

            // Menu Bar Items Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Menu Bar Items")
                        .font(.headline)

                    Spacer()

                    // Add button - only for specific models
                    Menu {
                        ForEach(availableModels) { model in
                            Button(model.displayLabel) {
                                addItem(modelKey: model.modelKey)
                            }
                        }
                    } label: {
                        Label("Add", systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                }

                Text("Each item appears as a separate status bar icon")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Primary item (always present - this is the MenuBarExtra)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Primary")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)

                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Antigravity Status")
                                .font(.system(.body, design: .default))
                            Text("Shows first model based on sort")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Additional items (specific models - can be removed)
                let additionalItems = menuBarItems.filter { $0.modelKey != nil }

                if !additionalItems.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Additional")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)

                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(additionalItems) { item in
                                    MenuBarItemRow(
                                        item: item,
                                        modelName: modelName(for: item),
                                        canRemove: true,
                                        onRemove: { removeItem(item) },
                                        onIconChange: { newIcon in
                                            AppSettings.shared.updateMenuBarItemIcon(id: item.id, icon: newIcon)
                                        }
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                    }
                }
            }
            .padding(10)
            .background(.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            // Footer
            HStack {
                let additionalCount = menuBarItems.filter { $0.modelKey != nil }.count
                let totalCount = 1 + additionalCount  // 1 primary + additional
                Text("\(totalCount) item\(totalCount == 1 ? "" : "s") in menu bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(20)
        .frame(width: 350, height: 350)
    }

    // MARK: - Helpers

    private func modelName(for item: MenuBarItem) -> String {
        if let key = item.modelKey {
            return availableModels.first { $0.modelKey == key }?.displayLabel ?? key
        }
        return "First (sorted)"
    }

    private func addItem(modelKey: String?) {
        settings.addMenuBarItem(for: modelKey)
        menuBarItems = settings.menuBarItems
    }

    private func removeItem(_ item: MenuBarItem) {
        settings.removeMenuBarItem(id: item.id)
        menuBarItems = settings.menuBarItems
    }
}

// MARK: - Menu Bar Item Row

struct MenuBarItemRow: View {
    let item: MenuBarItem
    let modelName: String
    let canRemove: Bool
    let onRemove: () -> Void
    let onIconChange: (String) -> Void

    @State private var showingIconPicker = false

    var body: some View {
        HStack {
            // Clickable icon with popover picker
            Button {
                showingIconPicker = true
            } label: {
                Image(systemName: item.icon)
                    .foregroundStyle(.blue)
                    .frame(width: 20)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingIconPicker) {
                iconPickerView
            }

            Text(modelName)
                .font(.system(.body, design: .default))
                .lineLimit(1)

            Spacer()

            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }

    private var iconPickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose Icon")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 32))], spacing: 8) {
                ForEach(MenuBarItem.availableIcons, id: \.self) { icon in
                    Button {
                        onIconChange(icon)
                        showingIconPicker = false
                    } label: {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .background(item.icon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(width: 200)
    }
}

#Preview {
    SettingsView(availableModels: [
        ModelQuota(modelKey: "claude", displayLabel: "Claude Sonnet 4.5", remainingFraction: 0.8, resetTime: Date().addingTimeInterval(3600), supportsImages: true, isNew: false),
        ModelQuota(modelKey: "gemini", displayLabel: "Gemini 3 Pro", remainingFraction: 1.0, resetTime: Date().addingTimeInterval(7200), supportsImages: true, isNew: false),
        ModelQuota(modelKey: "gpt", displayLabel: "GPT-OSS 120B", remainingFraction: 0.6, resetTime: Date().addingTimeInterval(1800), supportsImages: false, isNew: true)
    ])
}
