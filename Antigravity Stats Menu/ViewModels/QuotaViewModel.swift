//
//  QuotaViewModel.swift
//  Antigravity Stats Menu
//
//  Created by Krystian Lewandowski on 16/01/2026.
//

import Foundation
import SwiftUI

/// Observable ViewModel managing quota state and refresh logic
@Observable
final class QuotaViewModel {

    // MARK: - Published State

    private(set) var quotas: [ModelQuota] = []
    private(set) var userName: String?
    private(set) var userEmail: String?
    private(set) var tierName: String?
    private(set) var planName: String?
    private(set) var promptCredits: Int = 0
    private(set) var flowCredits: Int = 0
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var lastUpdate: Date?
    private(set) var isConnected = false

    /// Indicates if the last refresh used Cloud Code API (fresh data)
    private(set) var usedCloudCode = false

    // MARK: - Dependencies

    private let service = LanguageServerService()
    private let cloudCodeService = CloudCodeService()
    private var refreshTimer: Timer?

    // MARK: - Computed Properties

    /// Overall status for menu bar display
    var statusSummary: String {
        guard isConnected else { return "?" }

        if quotas.isEmpty {
            return "–"
        }

        // Show lowest remaining percentage across all models
        let minRemaining = quotas.map(\.remainingPercentage).min() ?? 100
        return "\(Int(minRemaining))%"
    }

    /// Verbose status for menu bar display showing first sorted model
    /// Format: "name │ %% │ time"
    var statusSummaryVerbose: String {
        guard isConnected else { return "?" }

        // Get first model based on current sort order
        guard let firstModel = firstSortedModel else {
            return "–"
        }

        let percent = "\(Int(firstModel.remainingPercentage))%"
        let time = firstModel.formattedResetTime

        return "\(firstModel.shortName) │ \(percent) │ \(time)"
    }

    /// First model based on current sort order (for primary menu bar item)
    var firstSortedModel: ModelQuota? {
        let sortOrder = AppSettings.shared.sortOrder
        return quotas.sorted { a, b in
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
        }.first
    }

    /// Menu bar icon based on status
    var statusIcon: String {
        if !isConnected {
            return "bolt.trianglebadge.exclamationmark.fill"
        }

        let minRemaining = quotas.map(\.remainingPercentage).min() ?? 100

        if minRemaining > 50 {
            return "bolt.fill"
        } else if minRemaining > 20 {
            return "bolt.badge.clock.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }

    /// The model with lowest remaining quota
    var lowestQuotaModel: ModelQuota? {
        quotas.min { $0.remainingFraction < $1.remainingFraction }
    }

    // MARK: - Actions

    /// Refresh quota data from local Language Server
    func refresh() async {
        isLoading = true
        error = nil

        do {
            // Fetch user status which includes all quota data
            let response = try await service.fetchUserStatus()

            // Update all state from the response
            quotas = response.toModelQuotas()
            userName = response.userName
            userEmail = response.userEmail
            tierName = response.tierName
            planName = response.planName
            promptCredits = response.promptCredits
            flowCredits = response.flowCredits

            isConnected = true
            lastUpdate = Date()
            error = nil
            usedCloudCode = false
        } catch {
            self.error = error.localizedDescription
            isConnected = false
            await service.invalidateConnection()
        }

        isLoading = false
    }

    /// Force refresh by trying Cloud Code API first for truly fresh data
    /// Falls back to local Language Server with connection invalidation
    func forceRefresh() async {
        isLoading = true
        error = nil

        // Try Cloud Code API first for fresh data
        do {
            let cloudQuotas = try await cloudCodeService.fetchAvailableModels()

            if !cloudQuotas.isEmpty {
                // Success! Use Cloud Code data
                quotas = cloudQuotas.map { $0.toModelQuota() }
                isConnected = true
                lastUpdate = Date()
                error = nil
                usedCloudCode = true
                isLoading = false

                // Also fetch user info from local server in background
                Task {
                    await fetchUserInfoOnly()
                }
                return
            }
        } catch {
            // Cloud Code failed, fall back to local server
            print("[CloudCode] Failed: \(error.localizedDescription), falling back to local")
        }

        // Fallback: invalidate connection and refresh from local server
        await service.invalidateConnection()
        await refresh()
    }

    /// Fetch only user info from local server (not quotas)
    private func fetchUserInfoOnly() async {
        do {
            let response = try await service.fetchUserStatus()
            userName = response.userName
            userEmail = response.userEmail
            tierName = response.tierName
            planName = response.planName
            promptCredits = response.promptCredits
            flowCredits = response.flowCredits
        } catch {
            // Ignore errors for background user info fetch
        }
    }

    /// Start periodic refresh
    func startAutoRefresh(interval: TimeInterval = 60) {
        stopAutoRefresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.refresh()
            }
        }

        // Initial fetch - use forceRefresh for fresh data on startup
        Task {
            await forceRefresh()
        }
    }

    /// Stop periodic refresh
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
