import AppKit
import SwiftUI

/// Native multiline editing keeps pasted text and keyboard submission separate.
struct MessageComposer: NSViewRepresentable {
    @Binding var text: String
    let isEnabled: Bool
    let send: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        let editor = ComposerTextView()
        editor.isRichText = false
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.drawsBackground = false
        editor.font = .systemFont(ofSize: Metrics.bodySize)
        editor.textColor = NSColor(Palette.ink)
        editor.insertionPointColor = NSColor(Palette.ink)
        editor.textContainerInset = NSSize(width: 8, height: 8)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.setAccessibilityLabel("Message DigDug")
        editor.delegate = context.coordinator
        scroll.documentView = editor
        updateNSView(scroll, context: context)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? ComposerTextView else { return }
        context.coordinator.parent = self
        editor.send = send
        editor.isEditable = isEnabled
        if editor.string != text { editor.string = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    /// Publishes native edits without replacing the text storage or selection.
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MessageComposer

        init(parent: MessageComposer) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
        }
    }
}

/// Handles Return locally, so it never activates the unrelated Stop button.
final class ComposerTextView: NSTextView {
    var send: () -> Void = {}

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 36 || event.keyCode == 76,
              !hasMarkedText() else {
            super.keyDown(with: event)
            return
        }
        guard isEditable else { return }
        if event.modifierFlags.contains(.shift) {
            insertNewline(nil)
        } else if event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            send()
        } else {
            super.keyDown(with: event)
        }
    }
}
