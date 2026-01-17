//
//  CloudCodeService.swift
//  Antigravity Stats Menu
//
//  Service to query Google's Cloud Code API directly for fresh quota data
//

import Foundation

/// Service to query Google's Cloud Code API for real-time quota information
actor CloudCodeService {

    // MARK: - Types

    struct CloudCodeQuota {
        let modelId: String
        let displayName: String
        let modelConstant: String
        let remainingFraction: Double
        let resetTime: Date?
        let supportsImages: Bool
        let supportsThinking: Bool
    }

    enum CloudCodeError: LocalizedError {
        case noCredentials
        case requestFailed(Int, String)
        case invalidResponse
        case projectResolutionFailed

        var errorDescription: String? {
            switch self {
            case .noCredentials:
                return "No Cloud Code credentials available"
            case .requestFailed(let status, let message):
                return "Cloud Code request failed (\(status)): \(message)"
            case .invalidResponse:
                return "Invalid Cloud Code response"
            case .projectResolutionFailed:
                return "Failed to resolve Cloud Code project"
            }
        }
    }

    // MARK: - API Endpoints

    private static let primaryBaseURL = "https://cloudcode-pa.googleapis.com"
    private static let fallbackBaseURL = "https://daily-cloudcode-pa.sandbox.googleapis.com"

    // MARK: - Properties

    private let credentialService = CredentialService()
    private var cachedProjectId: String?

    // MARK: - Public API

    /// Fetch available models with quota information directly from Cloud Code API
    func fetchAvailableModels() async throws -> [CloudCodeQuota] {
        let credentials = try await credentialService.getCredentials()

        // Resolve project ID if not cached
        let projectId = try await resolveProjectId(accessToken: credentials.accessToken, storedProjectId: credentials.projectId)

        // Fetch models
        return try await fetchModels(accessToken: credentials.accessToken, projectId: projectId)
    }

    /// Check if Cloud Code is available (credentials exist)
    func isAvailable() async -> Bool {
        return await credentialService.hasCredentials()
    }

    /// Invalidate cached data
    func invalidate() async {
        cachedProjectId = nil
        await credentialService.invalidate()
    }

    // MARK: - Project Resolution

    private func resolveProjectId(accessToken: String, storedProjectId: String?) async throws -> String {
        // Use cached or stored project ID if available
        if let projectId = cachedProjectId ?? storedProjectId {
            return projectId
        }

        // Call loadCodeAssist to get project ID
        let url = URL(string: "\(Self.primaryBaseURL)/v1internal:loadCodeAssist")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("antigravity", forHTTPHeaderField: "User-Agent")

        let payload: [String: Any] = [
            "metadata": [
                "ideType": "ANTIGRAVITY",
                "platform": "PLATFORM_UNSPECIFIED",
                "pluginType": "GEMINI"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CloudCodeError.requestFailed(statusCode, errorMessage)
        }

        // Parse response for project ID
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let projectInfo = json["cloudaicompanionProject"] as? [String: Any],
           let projectId = extractProjectId(from: projectInfo) {
            cachedProjectId = projectId
            return projectId
        }

        throw CloudCodeError.projectResolutionFailed
    }

    private func extractProjectId(from projectInfo: [String: Any]) -> String? {
        // Try different paths where project ID might be
        if let name = projectInfo["name"] as? String {
            return name
        }
        if let project = projectInfo["project"] as? String {
            return project
        }
        if let projectId = projectInfo["projectId"] as? String {
            return projectId
        }
        return nil
    }

    // MARK: - Model Fetching

    private func fetchModels(accessToken: String, projectId: String) async throws -> [CloudCodeQuota] {
        let url = URL(string: "\(Self.primaryBaseURL)/v1internal:fetchAvailableModels")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("antigravity", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        let payload: [String: Any] = ["project": projectId]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CloudCodeError.requestFailed(statusCode, errorMessage)
        }

        return try parseModelsResponse(data: data)
    }

    private func parseModelsResponse(data: Data) throws -> [CloudCodeQuota] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [String: Any] else {
            throw CloudCodeError.invalidResponse
        }

        let dateFormatter = ISO8601DateFormatter()
        var quotas: [CloudCodeQuota] = []

        for (modelId, modelData) in models {
            guard let info = modelData as? [String: Any] else { continue }

            let displayName = info["displayName"] as? String ?? modelId
            let modelConstant = info["model"] as? String ?? ""
            let supportsImages = info["supportsImages"] as? Bool ?? false
            let supportsThinking = info["supportsThinking"] as? Bool ?? false

            var remainingFraction: Double = 1.0
            var resetTime: Date?

            if let quotaInfo = info["quotaInfo"] as? [String: Any] {
                if let fraction = quotaInfo["remainingFraction"] as? Double {
                    remainingFraction = fraction
                }
                if let resetTimeStr = quotaInfo["resetTime"] as? String {
                    resetTime = dateFormatter.date(from: resetTimeStr)
                }
            }

            quotas.append(CloudCodeQuota(
                modelId: modelId,
                displayName: displayName,
                modelConstant: modelConstant,
                remainingFraction: remainingFraction,
                resetTime: resetTime,
                supportsImages: supportsImages,
                supportsThinking: supportsThinking
            ))
        }

        return quotas.sorted { $0.displayName < $1.displayName }
    }
}

// MARK: - Conversion to ModelQuota

extension CloudCodeService.CloudCodeQuota {
    /// Convert to the app's ModelQuota type
    func toModelQuota() -> ModelQuota {
        return ModelQuota(
            modelKey: modelConstant.isEmpty ? modelId : modelConstant,
            displayLabel: displayName,
            remainingFraction: remainingFraction,
            resetTime: resetTime,
            supportsImages: supportsImages,
            isNew: false
        )
    }
}
