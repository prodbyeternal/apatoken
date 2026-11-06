import SwiftUI

/// Dismiss on non-input taps without swallowing buttons, scrolling or text selection.
struct KeyboardDismissOnTap: UIViewRepresentable {
    func makeUIView(context: Context) -> DismissView { DismissView() }
    func updateUIView(_ uiView: DismissView, context: Context) {}

    final class DismissView: UIView, UIGestureRecognizerDelegate {
        private weak var attachedWindow: UIWindow?
        private var keyboardFrame = CGRect.zero
        private var observer: NSObjectProtocol?
        private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            tap.cancelsTouchesInView = false
            tap.delegate = self
            observer = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] notification in
                self?.keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            }
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attachedWindow?.removeGestureRecognizer(tap)
            attachedWindow = window
            window?.addGestureRecognizer(tap)
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }

        @objc private func dismissKeyboard() { attachedWindow?.endEditing(false) }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if let window = attachedWindow {
                let screenPoint = window.convert(touch.location(in: window), to: window.screen.coordinateSpace)
                if keyboardFrame.contains(screenPoint) { return false }
            }
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}
