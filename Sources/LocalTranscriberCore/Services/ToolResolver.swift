import Foundation

public struct ToolResolver: Sendable {
    public let searchPaths: [String]

    public init() {
        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let pathItems = environmentPath.split(separator: ":").map(String.init)
        searchPaths = pathItems + [
            "\(NSHomeDirectory())/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]
    }

    public func resolve(_ executableName: String) -> URL? {
        if executableName.contains("/") {
            let url = URL(fileURLWithPath: executableName)
            return isExecutable(url) ? url : nil
        }

        for directory in searchPaths {
            let url = URL(fileURLWithPath: directory).appendingPathComponent(executableName)
            if isExecutable(url) {
                return url
            }
        }

        return nil
    }

    private func isExecutable(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }
}
