import Foundation
import ServiceManagement

enum AdminHelperStatus: String, Sendable {
    case notRegistered = "Not Registered"
    case enabled = "Enabled"
    case requiresApproval = "Requires Approval"
    case notFound = "Not Found"

    var detail: String {
        switch self {
        case .notRegistered:
            return "The privileged helper has not been registered."
        case .enabled:
            return "Admin mode is available."
        case .requiresApproval:
            return "The helper needs approval in System Settings."
        case .notFound:
            return "The helper could not be found in this app bundle."
        }
    }
}

enum AdminHelperError: LocalizedError {
    case helperUnavailable(AdminHelperStatus)
    case rejected(String)
    case missingRemoteProxy

    var errorDescription: String? {
        switch self {
        case .helperUnavailable(let status):
            return "Admin mode is unavailable: \(status.detail)"
        case .rejected(let message):
            return message
        case .missingRemoteProxy:
            return "The privileged helper did not provide an XPC interface."
        }
    }
}

protocol LaunchdAdministering: Sendable {
    func status() -> AdminHelperStatus
    func registerHelper() throws -> AdminHelperStatus
    func openApprovalSettings()
    func performPrivileged(_ action: LaunchAction, on job: LaunchJob) async throws
}

struct SMAppServiceAdminClient: LaunchdAdministering {
    private var service: SMAppService {
        .daemon(plistName: launchTrollPrivilegedHelperPlistName)
    }

    func status() -> AdminHelperStatus {
        AdminHelperStatus(service.status)
    }

    func registerHelper() throws -> AdminHelperStatus {
        do {
            try service.register()
        } catch {
            let currentStatus = status()
            if currentStatus == .enabled || currentStatus == .requiresApproval {
                return currentStatus
            }
            throw error
        }
        return status()
    }

    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func performPrivileged(_ action: LaunchAction, on job: LaunchJob) async throws {
        let currentStatus = status()
        guard currentStatus == .enabled else {
            throw AdminHelperError.helperUnavailable(currentStatus)
        }

        let connection = NSXPCConnection(
            machServiceName: launchTrollPrivilegedHelperMachService,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: LaunchTrollPrivilegedHelperProtocol.self)
        connection.resume()
        defer { connection.invalidate() }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: error)
            } as? LaunchTrollPrivilegedHelperProtocol

            guard let proxy else {
                continuation.resume(throwing: AdminHelperError.missingRemoteProxy)
                return
            }

            proxy.performAction(action.rawValue, domain: job.domain.target, label: job.label) { success, message in
                if success.boolValue {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AdminHelperError.rejected(message ?? "The helper rejected the request."))
                }
            }
        }
    }
}

struct StaticAdminHelperClient: LaunchdAdministering {
    var helperStatus: AdminHelperStatus

    func status() -> AdminHelperStatus {
        helperStatus
    }

    func registerHelper() throws -> AdminHelperStatus {
        helperStatus
    }

    func openApprovalSettings() {}

    func performPrivileged(_ action: LaunchAction, on job: LaunchJob) async throws {
        _ = action
        _ = job
        throw AdminHelperError.helperUnavailable(helperStatus)
    }
}

private extension AdminHelperStatus {
    init(_ status: SMAppService.Status) {
        switch status {
        case .notRegistered:
            self = .notRegistered
        case .enabled:
            self = .enabled
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .notFound
        @unknown default:
            self = .notFound
        }
    }
}
