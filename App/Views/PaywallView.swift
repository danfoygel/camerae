import StoreKit
import SwiftUI

/// The Camerae Live subscription offer, shown when the play button is pressed after the free
/// trial (or from the trial badge, to subscribe early).
struct PaywallView: View {
    private static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacy = URL(string: "https://danfoygel.github.io/camerae/privacy.html")!

    @Environment(VideoAccess.self) private var access
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: VideoAccess.productIDs) {
            marketing
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .cancellation)
        .subscriptionStorePolicyDestination(url: Self.terms, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: Self.privacy, for: .privacyPolicy)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success(.verified(let transaction))) = result {
                await transaction.finish()
            }
            await access.refreshSubscription()
        }
        // Covers restores and purchases that finish outside this view, too.
        .onChange(of: access.isSubscribed) {
            if access.isSubscribed { dismiss() }
        }
    }

    private var marketing: some View {
        VStack(spacing: 14) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)
            Text("Camerae Live").font(.largeTitle.bold())
            Text(access.trialPhase == .ended
                 ? "Your free trial of live video has ended. Subscribe to keep watching."
                 : "Keep live video after your free trial.")
                .font(.headline)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 10) {
                Label("Live video from every camera that streams it", systemImage: "video.fill")
                Label("See snow, fog and backups before you leave", systemImage: "cloud.snow.fill")
                Label("Snapshots stay free for every camera", systemImage: "photo")
            }
            .font(.subheadline)
            .padding(.top, 4)
        }
        .padding(.horizontal)
        .padding(.top, 24)
    }
}
