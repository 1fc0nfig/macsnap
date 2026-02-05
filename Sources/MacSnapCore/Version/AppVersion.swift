import Foundation

public enum AppVersion {
    public static var current: String {
        if let envVersion = ProcessInfo.processInfo.environment["MACSNAP_VERSION"],
           !envVersion.isEmpty {
            return envVersion
        }

        if let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !shortVersion.isEmpty {
            return shortVersion
        }

        if let resourceVersion = bundledVersion,
           !resourceVersion.isEmpty {
            return resourceVersion
        }

        if let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           !buildVersion.isEmpty {
            return buildVersion
        }

        return "unknown"
    }

    private static var bundledVersion: String? {
        guard let url = Bundle.module.url(forResource: "version", withExtension: "txt") else {
            return nil
        }

        let value = try? String(contentsOf: url, encoding: .utf8)
        return value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
