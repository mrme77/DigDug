import AppKit
@preconcurrency import MarkdownUI
import SwiftUI

/// Copies visible prose as plain text, or a code block verbatim.
struct CopyResponseButton: View {
    let text: String
    var isCode = false
    @State private var copied = false
    @State private var failed = false

    var body: some View {
        Button {
            copied = Self.copy(text, isCode: isCode, to: .general)
            failed = !copied
        } label: {
            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.inkDim)
        .help(isCode ? "Copy code" : "Copy response as plain text")
        .accessibilityLabel(isCode ? "Copy code" : "Copy response as plain text")
        .disabled(text.isEmpty)
        .task(id: copied) {
            guard copied else { return }
            do { try await Task.sleep(nanoseconds: 1_500_000_000) }
            catch { return } // The feedback task ends when its view disappears.
            copied = false
        }
        .alert("Could not copy text", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The clipboard was unavailable. Please try again.")
        }
    }

    /// Uses the renderer's parser so lists, paragraphs, and code survive copying.
    static func copy(_ text: String, isCode: Bool, to pasteboard: NSPasteboard) -> Bool {
        let value = isCode ? text : MarkdownContent(text).renderPlainText()
        pasteboard.clearContents()
        return pasteboard.setString(value, forType: .string)
    }
}
