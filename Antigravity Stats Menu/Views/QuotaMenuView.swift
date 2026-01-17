//
//  QuotaMenuView.swift
//  Antigravity Stats Menu
//
//  Created by Krystian Lewandowski on 16/01/2026.
//

import SwiftUI

/// Main menu view displayed when clicking the status bar item
struct QuotaMenuView: View {
    let viewModel: QuotaViewModel
    let settings = AppSettings.shared

    @State private var sortOrder: QuotaSortOrder

    init(viewModel: QuotaViewModel) {
        self.viewModel = viewModel
        _sortOrder = State(initialValue: AppSettings.shared.sortOrder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerSection

            Divider()

            // Content
            if viewModel.isLoading && viewModel.quotas.isEmpty {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else if viewModel.quotas.isEmpty {
                emptyView
            } else {
                quotasList
            }

            Divider()

            // Footer
            footerSection
        }
        .padding(12)
        .frame(width: 380)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.blue)

            Text("Antigravity")
                .font(.headline)

            // Tier name badge (e.g., "Google AI Ultra")
            if let tierName = viewModel.tierName {
                Text(tierName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tierBadgeColor(for: tierName))
                    .clipShape(Capsule())
            }

            Spacer()

            if viewModel.isConnected {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func tierBadgeColor(for tier: String) -> Color {
        let lowerTier = tier.lowercased()
        if lowerTier.contains("ultra") { return .purple }
        if lowerTier.contains("pro") { return .blue }
        if lowerTier.contains("teams") || lowerTier.contains("enterprise") { return .orange }
        return .secondary
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("Connecting...")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No quota data available")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Quotas List (Compact Layout)

    private var quotasList: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Sort icons
            HStack(spacing: 12) {
                ForEach(SortType.allCases, id: \.self) { type in
                    SortButton(
                        type: type,
                        currentOrder: sortOrder,
                        action: {
                            if sortOrder.sortType == type {
                                // Same type - toggle direction
                                sortOrder = sortOrder.toggled
                            } else {
                                // Different type - switch to ascending
                                sortOrder = .ascending(for: type)
                            }
                            settings.sortOrder = sortOrder
                        }
                    )
                }

                Spacer()
            }

            // Compact quota rows
            VStack(alignment: .leading, spacing: 6) {
                ForEach(sortedQuotas) { quota in
                    CompactQuotaRow(quota: quota)
                }
            }
            .padding(8)
            .background(.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var sortedQuotas: [ModelQuota] {
        viewModel.quotas.sorted { a, b in
            switch sortOrder {
            case .nameAsc:
                return a.displayLabel < b.displayLabel
            case .nameDesc:
                return a.displayLabel > b.displayLabel
            case .usageAsc:
                return a.remainingFraction < b.remainingFraction
            case .usageDesc:
                return a.remainingFraction > b.remainingFraction
            case .resetTimeAsc:
                return (a.resetTime ?? .distantFuture) < (b.resetTime ?? .distantFuture)
            case .resetTimeDesc:
                return (a.resetTime ?? .distantFuture) > (b.resetTime ?? .distantFuture)
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            // Last update time
            if let lastUpdate = viewModel.lastUpdate {
                Text("Updated \(lastUpdate, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Settings button - native SettingsLink
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            // Refresh button
            Button {
                Task { await viewModel.forceRefresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isLoading)

            // Quit button
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Compact Quota Row

struct CompactQuotaRow: View {
    let quota: ModelQuota

    var body: some View {
        HStack(spacing: 8) {
            // Model name - fixed width to align bars
            Text(quota.displayLabel)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 200, alignment: .leading)
                .lineLimit(1)

            // Progress bar - fixed width, aligned
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.secondary.opacity(0.2))
                RoundedRectangle(cornerRadius: 2)
                    .fill(progressColor)
                    .frame(width: 60 * quota.remainingFraction)
            }
            .frame(width: 60, height: 6)

            // Percentage
            Text("\(Int(quota.remainingPercentage))%")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)

            // Reset time
            Text(quota.formattedResetTime)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }

    private var progressColor: Color {
        if quota.remainingPercentage > 50 {
            return .green
        } else if quota.remainingPercentage > 20 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Sort Button

struct SortButton: View {
    let type: SortType
    let currentOrder: QuotaSortOrder
    let action: () -> Void

    private var isSelected: Bool {
        currentOrder.sortType == type
    }

    private var isAscending: Bool {
        currentOrder.isAscending
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: type.icon)
                    .font(.system(size: 13))

                if isSelected {
                    Image(systemName: isAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundStyle(isSelected ? .blue : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 28)
            .background(isSelected ? .blue.opacity(0.15) : .secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    QuotaMenuView(viewModel: QuotaViewModel())
}
