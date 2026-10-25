import AppKit
import SwiftUI

/// Tracks user scrolling separately from programmatic streaming updates.
struct TranscriptScrollObserver: NSViewRepresentable {
    @Binding var followsLatest: Bool

    func makeNSView(context: Context) -> ScrollProbe {
        let probe = ScrollProbe()
        probe.onScroll = { followsLatest = $0 }
        return probe
    }

    func updateNSView(_ probe: ScrollProbe, context: Context) {
        probe.onScroll = { followsLatest = $0 }
    }

    /// Native live-scroll notifications fire for user gestures, not scrollTo calls.
    final class ScrollProbe: NSView {
        var onScroll: (Bool) -> Void = { _ in }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            guard window != nil else { return }
            NotificationCenter.default.addObserver(
                self, selector: #selector(didScroll(_:)),
                name: NSScrollView.didLiveScrollNotification, object: nil
            )
        }

        @objc private func didScroll(_ notification: Notification) {
            guard let scroll = notification.object as? NSScrollView,
                  scroll === enclosingScrollView,
                  let document = scroll.documentView else { return }
            let remaining = document.bounds.height - scroll.documentVisibleRect.maxY
            onScroll(remaining < 40)
        }
    }
}
