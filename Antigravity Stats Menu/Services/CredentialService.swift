//
//  CredentialService.swift
//  Antigravity Stats Menu
//
//  Extracts OAuth credentials from Antigravity's local storage
//

import Foundation
import SQLite3

/// Service to extract and manage Antigravity OAuth credentials
/// from the local VS Code/Cursor extension storage
actor CredentialService {

    // MARK: - Types

    struct Credentials {
        let accessToken: String
        let refreshToken: String
        let email: String
        let projectId: String?
        let expiresAt: Date?
    }

    enum CredentialError: LocalizedError {
        case databaseNotFound
        case databaseOpenFailed(String)
        case credentialsNotFound
        case tokenRefreshFailed(String)

        var errorDescription: String? {
            switch self {
            case .databaseNotFound:
                return "Antigravity credentials database not found"
            case .databaseOpenFailed(let message):
                return "Failed to open database: \(message)"
            case .credentialsNotFound:
                return "No stored credentials found"
            case .tokenRefreshFailed(let message):
                return "Token refresh failed: \(message)"
            }
        }
    }

    // MARK: - Properties

    private var cachedCredentials: Credentials?

    // MARK: - Public API

    /// Get valid credentials, refreshing if necessary
    func getCredentials() async throws -> Credentials {
        // Try cached credentials first
        if let cached = cachedCredentials,
           let expiresAt = cached.expiresAt,
           expiresAt > Date().addingTimeInterval(60) { // 1 minute buffer
            return cached
        }

        // Load from database
        let credentials = try loadCredentialsFromDatabase()

        // If we have expiration info and it's expired, try to refresh
        // Note: Antigravity auth format doesn't include expiration or refresh token
        // so we just use the token directly (Antigravity manages its own token refresh)
        if let expiresAt = credentials.expiresAt,
           expiresAt <= Date(),
           !credentials.refreshToken.isEmpty {
            // Refresh the token
            let refreshed = try await refreshAccessToken(refreshToken: credentials.refreshToken)
            cachedCredentials = refreshed
            return refreshed
        }

        cachedCredentials = credentials
        return credentials
    }

    /// Invalidate cached credentials
    func invalidate() {
        cachedCredentials = nil
    }

    /// Check if credentials are available
    func hasCredentials() -> Bool {
        do {
            let dbPath = try findDatabasePath()
            return FileManager.default.fileExists(atPath: dbPath)
        } catch {
            return false
        }
    }

    // MARK: - Database Access

    private func findDatabasePath() throws -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        // Look for Antigravity first (main database), then Cursor/VS Code extension databases
        let possiblePaths = [
            // Antigravity main database
            "Antigravity/User/globalStorage/state.vscdb",
            // Cursor extension paths
            "Cursor/User/globalStorage/google.geminicodeassist/state.vscdb",
            "com.cursor.Cursor/User/globalStorage/google.geminicodeassist/state.vscdb",
            // VS Code extension paths
            "Code/User/globalStorage/google.geminicodeassist/state.vscdb",
            "com.microsoft.VSCode/User/globalStorage/google.geminicodeassist/state.vscdb"
        ]

        for path in possiblePaths {
            let fullPath = appSupport.appendingPathComponent(path).path
            if FileManager.default.fileExists(atPath: fullPath) {
                return fullPath
            }
        }

        throw CredentialError.databaseNotFound
    }

    private func loadCredentialsFromDatabase() throws -> Credentials {
        let dbPath = try findDatabasePath()

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw CredentialError.databaseOpenFailed(errorMessage)
        }
        defer { sqlite3_close(db) }

        // Query all items from ItemTable
        let items = try queryItemTable(db: db!)

        // First, try Antigravity's native format (antigravityAuthStatus key containing JSON)
        if let authStatusJson = items["antigravityAuthStatus"],
           let credentials = parseAntigravityAuthStatus(authStatusJson) {
            return credentials
        }

        // Fallback: Try extension-style separate keys
        guard let accessToken = items["accessToken"] ?? items["google.geminicodeassist.accessToken"],
              let refreshToken = items["refreshToken"] ?? items["google.geminicodeassist.refreshToken"],
              let email = items["userEmail"] ?? items["google.geminicodeassist.userEmail"] ?? items["email"] else {
            throw CredentialError.credentialsNotFound
        }

        let projectId = items["projectId"] ?? items["google.geminicodeassist.projectId"]

        // Parse expiration time if available
        var expiresAt: Date?
        if let expiresAtStr = items["accessTokenExpiresAt"] ?? items["google.geminicodeassist.accessTokenExpiresAt"] {
            expiresAt = ISO8601DateFormatter().date(from: expiresAtStr)
                ?? parseEpochTimestamp(expiresAtStr)
        }

        return Credentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            email: email,
            projectId: projectId,
            expiresAt: expiresAt
        )
    }

    /// Parse Antigravity's native auth status JSON format
    /// Format: {"name":"...", "apiKey":"ya29...", "email":"...", ...}
    private func parseAntigravityAuthStatus(_ json: String) -> Credentials? {
        guard let data = json.data(using: .utf8) else { return nil }

        struct AuthStatus: Codable {
            let name: String?
            let apiKey: String?
            let email: String?
            // Note: refreshToken may not be present in this format
        }

        do {
            let status = try JSONDecoder().decode(AuthStatus.self, from: data)
            guard let apiKey = status.apiKey, let email = status.email else {
                return nil
            }

            // apiKey is the OAuth access token (ya29.xxx format)
            // Note: No refresh token available in this format - tokens are managed by Antigravity
            return Credentials(
                accessToken: apiKey,
                refreshToken: "", // Not available in this format
                email: email,
                projectId: nil,
                expiresAt: nil // Unknown - Antigravity manages expiration
            )
        } catch {
            return nil
        }
    }

    private func queryItemTable(db: OpaquePointer) throws -> [String: String] {
        var items: [String: String] = [:]

        let query = "SELECT key, value FROM ItemTable"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return items
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let keyPtr = sqlite3_column_text(statement, 0),
                  let valuePtr = sqlite3_column_text(statement, 1) else {
                continue
            }

            let key = String(cString: keyPtr)
            let value = String(cString: valuePtr)
            items[key] = value
        }

        return items
    }

    private func parseEpochTimestamp(_ string: String) -> Date? {
        guard let timestamp = Double(string) else { return nil }
        // Handle milliseconds if the number is large
        if timestamp > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: timestamp / 1000)
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    // MARK: - Token Refresh

    private func refreshAccessToken(refreshToken: String) async throws -> Credentials {
        // Google OAuth2 token endpoint
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

        // Client credentials for Antigravity (from the extension)
        // These are public client IDs for installed applications
        let clientId = "77185425430.apps.googleusercontent.com"

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId
        ]
        request.httpBody = body.map { "\($0)=\($1)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CredentialError.tokenRefreshFailed(errorMessage)
        }

        struct TokenResponse: Codable {
            let access_token: String
            let expires_in: Int
            let token_type: String
            let scope: String?
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Get email from cached credentials or return placeholder
        let email = cachedCredentials?.email ?? "unknown@google.com"

        return Credentials(
            accessToken: tokenResponse.access_token,
            refreshToken: refreshToken,
            email: email,
            projectId: cachedCredentials?.projectId,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        )
    }
}
