//
//  QuotaModels.swift
//  Antigravity Stats Menu
//
//  Created by Krystian Lewandowski on 16/01/2026.
//

import Foundation

// MARK: - API Response Models (GetUserStatus endpoint)

/// Root response from GetUserStatus endpoint
struct UserStatusResponse: Codable {
    let userStatus: UserStatus?
}

struct UserStatus: Codable {
    let name: String?
    let email: String?
    let planStatus: PlanStatus?
    let cascadeModelConfigData: CascadeModelConfigData?
    let userTier: UserTier?
}

struct PlanStatus: Codable {
    let planInfo: PlanInfo?
    let availablePromptCredits: Int?
    let availableFlowCredits: Int?
}

struct PlanInfo: Codable {
    let planName: String?
    let teamsTier: String?
}

struct UserTier: Codable {
    let id: String?
    let name: String?
    let description: String?
}

struct CascadeModelConfigData: Codable {
    let clientModelConfigs: [ClientModelConfig]?
}

struct ClientModelConfig: Codable {
    let label: String?
    let modelOrAlias: ModelOrAlias?
    let supportsImages: Bool?
    let isRecommended: Bool?
    let quotaInfo: QuotaInfo?
    let tagTitle: String?
}

struct ModelOrAlias: Codable {
    let model: String?
}

struct QuotaInfo: Codable {
    let remainingFraction: Double?
    let resetTime: String?  // ISO 8601 format: "2026-01-17T03:29:40Z"
}

// MARK: - View Models

/// Processed model quota for display
struct ModelQuota: Identifiable {
    var id: String { modelKey }

    let modelKey: String
    let displayLabel: String
    let remainingFraction: Double
    let resetTime: Date?
    let supportsImages: Bool
    let isNew: Bool

    var remainingPercentage: Double {
        remainingFraction * 100
    }

    /// Short name for compact display (e.g., "Claude 4.5" from "Claude Sonnet 4.5 (Thinking)")
    var shortName: String {
        // Remove common suffixes and parenthetical notes
        var name = displayLabel
            .replacingOccurrences(of: " (Thinking)", with: "")
            .replacingOccurrences(of: " (Medium)", with: "")
            .replacingOccurrences(of: "Sonnet ", with: "")
            .replacingOccurrences(of: "Opus ", with: "")

        // Truncate if still too long
        if name.count > 12 {
            name = String(name.prefix(12))
        }
        return name
    }

    var timeUntilReset: TimeInterval? {
        guard let resetTime else { return nil }
        return resetTime.timeIntervalSinceNow
    }

    var formattedResetTime: String {
        guard let interval = timeUntilReset, interval > 0 else {
            return "Reset pending"
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var statusColor: String {
        if remainingFraction <= 0.1 {
            return "red"
        } else if remainingFraction <= 0.3 {
            return "yellow"
        } else {
            return "green"
        }
    }

    var statusEmoji: String {
        if remainingFraction <= 0.1 {
            return "🔴"
        } else if remainingFraction <= 0.3 {
            return "🟡"
        } else {
            return "🟢"
        }
    }
}

// MARK: - Response Processing

extension UserStatusResponse {
    /// Convert API response to display-ready model quotas
    func toModelQuotas() -> [ModelQuota] {
        guard let configs = userStatus?.cascadeModelConfigData?.clientModelConfigs else {
            return []
        }

        let dateFormatter = ISO8601DateFormatter()

        return configs.compactMap { config -> ModelQuota? in
            guard let label = config.label,
                  let quotaInfo = config.quotaInfo else {
                return nil
            }

            let resetDate: Date?
            if let resetTimeString = quotaInfo.resetTime {
                resetDate = dateFormatter.date(from: resetTimeString)
            } else {
                resetDate = nil
            }

            return ModelQuota(
                modelKey: config.modelOrAlias?.model ?? label,
                displayLabel: label,
                remainingFraction: quotaInfo.remainingFraction ?? 1.0,
                resetTime: resetDate,
                supportsImages: config.supportsImages ?? false,
                isNew: config.tagTitle == "New"
            )
        }
        .sorted { $0.displayLabel < $1.displayLabel }
    }

    /// Get the lowest quota model (for status bar display)
    func lowestQuotaModel() -> ModelQuota? {
        toModelQuotas().min { $0.remainingFraction < $1.remainingFraction }
    }

    /// Get user display info
    var userName: String {
        userStatus?.name ?? "Unknown"
    }

    var userEmail: String {
        userStatus?.email ?? ""
    }

    var tierName: String {
        userStatus?.userTier?.name ?? userStatus?.planStatus?.planInfo?.planName ?? "Unknown"
    }

    var planName: String {
        userStatus?.planStatus?.planInfo?.planName ?? "Free"
    }

    var promptCredits: Int {
        userStatus?.planStatus?.availablePromptCredits ?? 0
    }

    var flowCredits: Int {
        userStatus?.planStatus?.availableFlowCredits ?? 0
    }
}
