import Foundation

public struct ToolResolver: Sendable {
    public let searchPaths: [String]

    public init(extraPaths: [String] = []) {
        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let pathItems = environmentPath.split(separator: ":").map(String.init)
        let defaults = [
            "\(NSHomeDirectory())/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]

        var seen = Set<String>()
        searchPaths = (extraPaths + pathItems + defaults).filter { path in
            guard !path.isEmpty, !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }
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
