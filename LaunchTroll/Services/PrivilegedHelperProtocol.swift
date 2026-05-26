import Foundation

var launchTrollPrivilegedHelperMachService: String {
    "\(Bundle.main.bundleIdentifier ?? "com.example.LaunchTroll").PrivilegedHelper"
}

var launchTrollPrivilegedHelperPlistName: String {
    "\(launchTrollPrivilegedHelperMachService).plist"
}

@objc protocol LaunchTrollPrivilegedHelperProtocol {
    func performAction(
        _ action: String,
        domain: String,
        label: String,
        withReply reply: @escaping (NSNumber, String?) -> Void
    )
}
