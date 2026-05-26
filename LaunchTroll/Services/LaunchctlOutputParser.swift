import Foundation

struct LaunchctlServiceStatus: Hashable, Sendable {
    var label: String
    var pid: Int?
    var lastExitStatus: Int?
    var line: String
}

enum LaunchctlOutputParser {
    static func parseServices(from domainOutput: String) -> [LaunchctlServiceStatus] {
        var statuses: [LaunchctlServiceStatus] = []
        var insideServices = false

        for line in domainOutput.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "services = {" {
                insideServices = true
                continue
            }

            if insideServices, trimmed == "}" {
                break
            }

            guard insideServices, !trimmed.isEmpty else {
                continue
            }

            let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 3 else {
                continue
            }

            let label = String(parts.last ?? "")
            guard label.contains(".") || label.hasPrefix("application.") else {
                continue
            }

            let pidValue = Int(parts[0]).flatMap { $0 > 0 ? $0 : nil }
            let statusToken = parts.dropFirst().dropLast().last.map(String.init)
            let lastExitStatus = statusToken.flatMap { Int($0) }

            statuses.append(
                LaunchctlServiceStatus(
                    label: label,
                    pid: pidValue,
                    lastExitStatus: lastExitStatus,
                    line: trimmed
                )
            )
        }

        return statuses
    }

    static func parseDisabledServices(from disabledOutput: String) -> [String: Bool] {
        let pattern = #""([^"]+)"\s*=>\s*(enabled|disabled)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return [:]
        }

        let range = NSRange(disabledOutput.startIndex..<disabledOutput.endIndex, in: disabledOutput)
        let matches = expression.matches(in: disabledOutput, range: range)

        return matches.reduce(into: [String: Bool]()) { result, match in
            guard
                let labelRange = Range(match.range(at: 1), in: disabledOutput),
                let stateRange = Range(match.range(at: 2), in: disabledOutput)
            else {
                return
            }

            let label = String(disabledOutput[labelRange])
            let state = String(disabledOutput[stateRange])
            result[label] = state == "disabled"
        }
    }
}
