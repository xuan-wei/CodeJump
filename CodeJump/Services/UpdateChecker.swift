import Foundation
import Combine
import SwiftUI

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var latestVersion: String?
    @Published var hasUpdate = false
    @Published var releaseURL: URL?
    @Published var isChecking = false

    @AppStorage("lastUpdateCheck") private var lastCheck: Double = 0
    @AppStorage("skippedVersion") private var skippedVersion: String = ""

    private var timer: AnyCancellable?
    private let repoURL = "https://api.github.com/repos/xuan-wei/CodeJump/releases/latest"

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private init() {
        if Date().timeIntervalSince1970 - lastCheck > 86400 {
            Task { await check(manual: false) }
        }
        timer = Timer.publish(every: 86400, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.check(manual: false) }
            }
    }

    func checkNow() {
        skippedVersion = ""
        Task { await check(manual: true) }
    }

    func skipCurrentVersion() {
        if let ver = latestVersion {
            skippedVersion = ver
            hasUpdate = false
        }
    }

    private func check(manual: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        guard let url = URL(string: repoURL) else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            let tagName = (json["tag_name"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let remote = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            let htmlURL = json["html_url"] as? String

            latestVersion = remote
            releaseURL = htmlURL.flatMap { URL(string: $0) }
            let newer = isNewer(remote: remote, local: currentVersion)
            hasUpdate = newer && (manual || remote != skippedVersion)
            lastCheck = Date().timeIntervalSince1970
        } catch {
            // Silently fail — update check is best-effort
        }
    }

    private func isNewer(remote: String, local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        let count = max(r.count, l.count)
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}
