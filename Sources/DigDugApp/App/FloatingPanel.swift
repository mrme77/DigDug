import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, deferringCreate: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: backing,
            defer: deferringCreate
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Seamless dark chrome: hide the native title, blend the titlebar into the
        // dark UI, and let the user drag the panel by its body.
        title = "DigDug"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        backgroundColor = NSColor(red: 0.067, green: 0.071, blue: 0.086, alpha: 1.0)
    }
}
