import Foundation

struct CommandResult: Sendable {
    var status: Int32
    var output: String
    var errorOutput: String

    var combinedOutput: String {
        [output, errorOutput]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

enum CommandRunnerError: LocalizedError {
    case nonZeroExit(executable: String, arguments: [String], result: CommandResult)

    var errorDescription: String? {
        switch self {
        case .nonZeroExit(let executable, let arguments, let result):
            let command = ([executable] + arguments).joined(separator: " ")
            let detail = result.combinedOutput.isEmpty ? "No output." : result.combinedOutput
            return "\(command) exited with status \(result.status).\n\(detail)"
        }
    }
}

protocol CommandRunning: Sendable {
    func run(_ executableURL: URL, arguments: [String]) async throws -> CommandResult
}

struct FoundationProcessRunner: CommandRunning {
    func run(_ executableURL: URL, arguments: [String]) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = executableURL
                process.arguments = arguments
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    var outputData = Data()
                    var errorData = Data()
                    let outputGroup = DispatchGroup()

                    outputGroup.enter()
                    DispatchQueue.global(qos: .utility).async {
                        outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        outputGroup.leave()
                    }

                    outputGroup.enter()
                    DispatchQueue.global(qos: .utility).async {
                        errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        outputGroup.leave()
                    }

                    try process.run()
                    process.waitUntilExit()
                    outputGroup.wait()

                    let result = CommandResult(
                        status: process.terminationStatus,
                        output: String(data: outputData, encoding: .utf8) ?? "",
                        errorOutput: String(data: errorData, encoding: .utf8) ?? ""
                    )

                    guard result.status == 0 else {
                        continuation.resume(
                            throwing: CommandRunnerError.nonZeroExit(
                                executable: executableURL.path,
                                arguments: arguments,
                                result: result
                            )
                        )
                        return
                    }

                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
