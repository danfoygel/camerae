import CamCore
import Foundation
import Security
import StoreKit
import os

private let log = Logger(subsystem: "com.camerae.app", category: "access")

/// Whether live video plays. Live video is a subscription, free for 72 hours from the first time
/// a video plays. Without access, cameras show their snapshot and a play button, which starts the
/// trial the first time and opens the paywall once it's over.
@MainActor @Observable
final class VideoAccess {
    /// The subscriptions that unlock live video: one subscription group in App Store Connect.
    static let productIDs = ["com.danfoygel.camerae.live.yearly", "com.danfoygel.camerae.live.monthly"]

    private(set) var isSubscribed = false
    private(set) var trialPhase: VideoTrial.Phase
    var isPaywallPresented = false

    var hasVideo: Bool { isSubscribed || trialPhase.isActive }

    /// When the trial runs out, while it's running and there's no subscription.
    var trialEndsAt: Date? {
        guard !isSubscribed, case .active(let end) = trialPhase else { return nil }
        return end
    }

    private var trial: VideoTrial
    private var trialEnd: Task<Void, Never>?
    private var listeners: [Task<Void, Never>] = []

    init() {
        var trial = VideoTrial(startedAt: TrialKeychain.startDate)
        #if DEBUG
        // Development shortcuts: launch with `-resetVideoTrial YES` and/or `-videoTrialSeconds 60`.
        if UserDefaults.standard.bool(forKey: "resetVideoTrial") {
            TrialKeychain.startDate = nil
            trial.startedAt = nil
        }
        let seconds = UserDefaults.standard.double(forKey: "videoTrialSeconds")
        if seconds > 0 { trial.length = seconds }
        #endif
        self.trial = trial
        trialPhase = trial.phase(at: .now)
        scheduleTrialEnd()

        // Renewals, refunds, purchases on another device, and restores arrive here.
        listeners = [
            Task { [weak self] in
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update { await transaction.finish() }
                    await self?.refreshSubscription()
                }
            },
            Task { [weak self] in
                for await _ in Product.SubscriptionInfo.Status.updates {
                    await self?.refreshSubscription()
                }
            },
        ]
    }

    /// Re-reads the trial and the subscription: at launch and whenever the app comes forward.
    func refresh() async {
        updateTrial()
        await refreshSubscription()
    }

    /// The play button: starts the free trial the first time, otherwise opens the paywall.
    func requestVideo() {
        guard !isSubscribed else { return }
        switch trialPhase {
        case .notStarted:
            let now = Date.now
            trial.startedAt = now
            TrialKeychain.startDate = now
            log.notice("video trial started")
            updateTrial()
        case .active:
            break
        case .ended:
            isPaywallPresented = true
        }
    }

    func refreshSubscription() async {
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            subscribed = true
        }
        isSubscribed = subscribed
    }

    private func updateTrial() {
        trialPhase = trial.phase(at: .now)
        scheduleTrialEnd()
    }

    /// Stops video the moment the trial runs out, not just at the next launch.
    private func scheduleTrialEnd() {
        trialEnd?.cancel()
        guard case .active(let end) = trialPhase else { return }
        trialEnd = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(end.timeIntervalSinceNow, 0)))
            guard !Task.isCancelled else { return }
            self?.updateTrial()
        }
    }
}

/// Where the trial's start is kept. Keychain items outlive deleting and reinstalling the app,
/// so a reinstall doesn't restart the trial.
private enum TrialKeychain {
    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.danfoygel.camerae.video-trial",
            kSecAttrAccount as String: "start",
        ]
    }

    static var startDate: Date? {
        get {
            var query = query
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data,
                  let seconds = Double(String(decoding: data, as: UTF8.self)) else { return nil }
            return Date(timeIntervalSince1970: seconds)
        }
        set {
            SecItemDelete(query as CFDictionary)
            guard let newValue else { return }
            var query = query
            query[kSecValueData as String] = Data(String(newValue.timeIntervalSince1970).utf8)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess { log.error("couldn't save the trial start: \(status)") }
        }
    }
}
