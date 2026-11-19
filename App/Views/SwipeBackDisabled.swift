import SwiftUI
import UIKit

extension View {
    /// Turns off the navigation stack's swipe-to-go-back gestures while this view is on screen,
    /// so horizontal swipes in the content don't pop it. The back button still works.
    func swipeBackDisabled() -> some View {
        background(SwipeBackDisabler().frame(width: 0, height: 0))
    }
}

private struct SwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            setSwipeBack(enabled: false)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            setSwipeBack(enabled: true)
        }

        private func setSwipeBack(enabled: Bool) {
            guard let navigation = navigationController else { return }
            // Edge swipe, plus iOS 26's swipe from anywhere in the content.
            navigation.interactivePopGestureRecognizer?.isEnabled = enabled
            if #available(iOS 26, *) {
                navigation.interactiveContentPopGestureRecognizer?.isEnabled = enabled
            }
        }
    }
}
