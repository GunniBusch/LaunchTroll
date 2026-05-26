import Foundation

private let machServiceName = ProcessInfo.processInfo.processName

@objc private protocol LaunchTrollPrivilegedHelperProtocol {
    func performAction(
        _ action: String,
        domain: String,
        label: String,
        withReply reply: @escaping (NSNumber, String?) -> Void
    )
}

private final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: LaunchTrollPrivilegedHelperProtocol.self)
        newConnection.exportedObject = PrivilegedLaunchdService()
        newConnection.resume()
        return true
    }
}

private final class PrivilegedLaunchdService: NSObject, LaunchTrollPrivilegedHelperProtocol {
    func performAction(
        _ action: String,
        domain: String,
        label: String,
        withReply reply: @escaping (NSNumber, String?) -> Void
    ) {
        do {
            let arguments = try arguments(for: action, domain: domain, label: label)
            let result = try runLaunchctl(arguments)
            if result.status == 0 {
                reply(true, nil)
            } else {
                reply(false, result.message)
            }
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    private func arguments(for action: String, domain: String, label: String) throws -> [String] {
        guard domain == "system" else {
            throw HelperError.rejectedDomain
        }

        guard isValidLabel(label) else {
            throw HelperError.invalidLabel
        }

        let target = "\(domain)/\(label)"
        switch action {
        case "enable":
            return ["enable", target]
        case "disable":
            return ["disable", target]
        case "kickstart":
            return ["kickstart", target]
        case "restart":
            return ["kickstart", "-k", target]
        case "stop":
            return ["kill", "TERM", target]
        default:
            throw HelperError.rejectedAction
        }
    }

    private func isValidLabel(_ label: String) -> Bool {
        guard !label.isEmpty, label.count < 256 else {
            return false
        }

        return label.allSatisfy { character in
            character.isLetter || character.isNumber || character == "." || character == "-" || character == "_"
        }
    }

    private func runLaunchctl(_ arguments: [String]) throws -> HelperCommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return HelperCommandResult(status: process.terminationStatus, output: output, errorOutput: errorOutput)
    }
}

private enum HelperError: LocalizedError {
    case rejectedDomain
    case rejectedAction
    case invalidLabel

    var errorDescription: String? {
        switch self {
        case .rejectedDomain:
            return "The privileged helper only accepts system-domain requests."
        case .rejectedAction:
            return "The requested launchd action is not allowed."
        case .invalidLabel:
            return "The launchd label contains unsupported characters."
        }
    }
}

private struct HelperCommandResult {
    var status: Int32
    var output: String
    var errorOutput: String

    var message: String {
        let text = [output, errorOutput]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return text.isEmpty ? "launchctl exited with status \(status)." : text
    }
}

private let delegate = HelperDelegate()
private let listener = NSXPCListener(machServiceName: machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
