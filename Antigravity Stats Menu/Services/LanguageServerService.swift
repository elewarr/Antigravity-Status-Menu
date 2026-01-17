//
//  LanguageServerService.swift
//  Antigravity Stats Menu
//
//  Created by Krystian Lewandowski on 16/01/2026.
//

import Foundation
import Darwin

/// Service to discover and communicate with the local Antigravity Language Server
/// Uses native Darwin APIs instead of shell commands for sandbox compatibility
actor LanguageServerService {

    // MARK: - Types

    struct ConnectionInfo {
        let pid: pid_t
        let csrfToken: String
        let port: UInt16
    }

    enum ServiceError: LocalizedError {
        case processNotFound
        case csrfTokenNotFound
        case portNotFound
        case connectionFailed(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .processNotFound:
                return "Antigravity Language Server not running"
            case .csrfTokenNotFound:
                return "Could not extract CSRF token"
            case .portNotFound:
                return "Could not find listening port"
            case .connectionFailed(let message):
                return "Connection failed: \(message)"
            case .invalidResponse:
                return "Invalid response from server"
            }
        }
    }

    // MARK: - Properties

    private var cachedConnection: ConnectionInfo?

    // MARK: - Public API

    /// Fetch user status and quota data from the language server
    func fetchUserStatus() async throws -> UserStatusResponse {
        let connection = try await getConnection()
        return try await queryUserStatus(connection: connection)
    }

    /// Force reconnection on next request
    func invalidateConnection() {
        cachedConnection = nil
    }

    // MARK: - Connection Discovery

    private func getConnection() async throws -> ConnectionInfo {
        if let cached = cachedConnection {
            return cached
        }

        let connection = try await discoverConnection()
        cachedConnection = connection
        return connection
    }

    private func discoverConnection() async throws -> ConnectionInfo {
        // Step 1: Find the language server process using native APIs
        let processInfo = try findLanguageServerProcess()

        // Step 2: Extract CSRF token from process arguments
        let csrfToken = try extractCSRFToken(from: processInfo.arguments)

        // Step 3: Find the listening port using native socket APIs
        let port = try findListeningPort(for: processInfo.pid)

        return ConnectionInfo(pid: processInfo.pid, csrfToken: csrfToken, port: port)
    }

    // MARK: - Native Process Discovery (libproc)

    private func findLanguageServerProcess() throws -> (pid: pid_t, arguments: String) {
        // Get count of all processes
        var numberOfProcesses = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard numberOfProcesses > 0 else {
            throw ServiceError.processNotFound
        }

        // Allocate buffer for PIDs
        let pidCount = Int(numberOfProcesses) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: pidCount)

        numberOfProcesses = proc_listpids(
            UInt32(PROC_ALL_PIDS),
            0,
            &pids,
            Int32(pids.count * MemoryLayout<pid_t>.size)
        )

        let actualPidCount = Int(numberOfProcesses) / MemoryLayout<pid_t>.size

        // Iterate through processes looking for language_server_macos
        for i in 0..<actualPidCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            // Get process path (MAXPATHLEN is 1024)
            var pathBuffer = [CChar](repeating: 0, count: 1024)
            let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))

            guard pathLength > 0 else { continue }

            let processPath = String(cString: pathBuffer)

            // Check if this is an Antigravity language server
            if processPath.contains("language_server_macos") {
                // Get process arguments using sysctl
                if let args = getProcessArguments(pid: pid),
                   args.contains("--csrf_token"),
                   args.contains("--app_data_dir") && args.contains("antigravity") {
                    return (pid, args)
                }
            }
        }

        throw ServiceError.processNotFound
    }

    /// Get process arguments using sysctl
    private func getProcessArguments(pid: pid_t) -> String? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]

        // First call to get the size
        var size: Int = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0 else {
            return nil
        }

        // Allocate buffer
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0 else {
            return nil
        }

        // Parse the buffer - it starts with argc (4 bytes), then the executable path,
        // then null bytes, then the arguments
        guard size >= 4 else { return nil }

        // Convert buffer to string, dealing with null separators
        var result = ""
        var inArg = false
        var skipToArg = true  // Skip until we hit the first argument

        for i in 4..<size {
            let char = buffer[i]
            if char == 0 {
                if inArg {
                    result += " "
                    inArg = false
                }
                skipToArg = false
            } else if !skipToArg {
                let scalar = Unicode.Scalar(UInt8(bitPattern: char))
                result.append(Character(scalar))
                inArg = true
            }
        }

        return result.isEmpty ? nil : result
    }

    private func extractCSRFToken(from arguments: String) throws -> String {
        // Look for --csrf_token followed by the token value
        let pattern = #"--csrf_token[=\s]+([a-f0-9-]+)"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: arguments, options: [], range: NSRange(arguments.startIndex..., in: arguments)),
           let tokenRange = Range(match.range(at: 1), in: arguments) {
            return String(arguments[tokenRange])
        }

        throw ServiceError.csrfTokenNotFound
    }

    // MARK: - Native Port Discovery (libproc)

    private func findListeningPort(for pid: pid_t) throws -> UInt16 {
        // Get file descriptor info for this process
        let bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bufferSize > 0 else {
            throw ServiceError.portNotFound
        }

        let fdCount = Int(bufferSize) / MemoryLayout<proc_fdinfo>.size
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: fdCount)

        let actualSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, bufferSize)
        let actualCount = Int(actualSize) / MemoryLayout<proc_fdinfo>.size

        // Look for socket file descriptors
        for i in 0..<actualCount {
            let fd = fds[i]

            // Check if this is a socket (PROX_FDTYPE_SOCKET = 2)
            guard fd.proc_fdtype == PROX_FDTYPE_SOCKET else { continue }

            // Get socket info
            var socketInfo = socket_fdinfo()
            let socketInfoSize = Int32(MemoryLayout<socket_fdinfo>.size)

            let result = proc_pidfdinfo(
                pid,
                fd.proc_fd,
                PROC_PIDFDSOCKETINFO,
                &socketInfo,
                socketInfoSize
            )

            guard result == socketInfoSize else { continue }

            // Check if it's a TCP socket in LISTEN state
            // TCP LISTEN state = 1 (TCPS_LISTEN)
            let sockInfo = socketInfo.psi

            // Check for IPv4 TCP listening socket
            if sockInfo.soi_family == Int32(AF_INET) &&
               sockInfo.soi_kind == SOCKINFO_TCP &&
               sockInfo.soi_proto.pri_tcp.tcpsi_state == 1 {  // TCPS_LISTEN

                let portRaw = sockInfo.soi_proto.pri_tcp.tcpsi_ini.insi_lport
                let hostPort = UInt16(bigEndian: UInt16(truncatingIfNeeded: portRaw))

                if hostPort > 0 {
                    return hostPort
                }
            }

            // Check for IPv6 TCP listening socket
            if sockInfo.soi_family == Int32(AF_INET6) &&
               sockInfo.soi_kind == SOCKINFO_TCP &&
               sockInfo.soi_proto.pri_tcp.tcpsi_state == 1 {  // TCPS_LISTEN

                let portRaw = sockInfo.soi_proto.pri_tcp.tcpsi_ini.insi_lport
                let hostPort = UInt16(bigEndian: UInt16(truncatingIfNeeded: portRaw))

                if hostPort > 0 {
                    return hostPort
                }
            }
        }

        throw ServiceError.portNotFound
    }

    // MARK: - API Requests

    private func queryUserStatus(connection: ConnectionInfo) async throws -> UserStatusResponse {
        let url = URL(string: "https://127.0.0.1:\(connection.port)/exa.language_server_pb.LanguageServerService/GetUserStatus")!

        let data = try await makeRequest(to: url, csrfToken: connection.csrfToken)

        // API returns camelCase JSON which matches our Swift property names
        let decoder = JSONDecoder()

        return try decoder.decode(UserStatusResponse.self, from: data)
    }

    private func makeRequest(to url: URL, csrfToken: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(csrfToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")
        request.httpBody = "{}".data(using: .utf8)

        // Create a session that ignores SSL certificate validation for localhost
        let session = URLSession(configuration: .default, delegate: InsecureDelegate(), delegateQueue: nil)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ServiceError.connectionFailed("HTTP error")
        }

        return data
    }
}

// MARK: - SSL Delegate for localhost

private class InsecureDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        // Only trust localhost connections
        if challenge.protectionSpace.host == "127.0.0.1" {
            return (.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
        }
        return (.performDefaultHandling, nil)
    }
}
