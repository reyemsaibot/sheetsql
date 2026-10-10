import SwiftUI
import AppKit

@MainActor
final class SQLEditorController {
    weak var editor: NSTextView?
    func insertIdentifier(_ name: String) {
        guard let editor else { return }
        editor.window?.makeFirstResponder(editor)
        editor.breakUndoCoalescing()
        editor.insertText(quoted(name), replacementRange: editor.selectedRange())
        editor.breakUndoCoalescing()
        editor.scrollRangeToVisible(editor.selectedRange())
    }
    func focus() {
        guard let editor else { return }
        editor.window?.makeFirstResponder(editor)
    }
}

/// Plain code input: macOS prose substitutions must never change SQL syntax.
struct SQLEditor: NSViewRepresentable {
    @Binding var text: String
    let controller: SQLEditorController
    var suggestions: [String] = []

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, suggestions: suggestions) }

    func makeNSView(context: Context) -> SQLEditorContainer {
        let container = SQLEditorContainer()
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let editor = NSTextView()
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.isGrammarCheckingEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        editor.isAutomaticDataDetectionEnabled = false
        editor.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        editor.textColor = .textColor
        editor.drawsBackground = false
        editor.textContainerInset = NSSize(width: 8, height: 5)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        editor.setAccessibilityLabel("SQL-Abfrage")
        editor.string = text
        editor.delegate = context.coordinator
        scroll.documentView = editor
        container.embed(scroll: scroll)
        controller.editor = editor
        context.coordinator.highlight(editor)
        context.coordinator.updateGutter(in: container, text: editor.string)
        return container
    }

    func updateNSView(_ container: SQLEditorContainer, context: Context) {
        context.coordinator.text = $text
        context.coordinator.suggestions = suggestions
        guard let editor = controller.editor, editor.string != text else { return }
        // External changes (sheet selection/history) must replace the editor contents;
        // keystroke updates must retain the selection and native undo stack.
        editor.string = text
        context.coordinator.highlight(editor)
        context.coordinator.updateGutter(in: container, text: text)
        editor.undoManager?.removeAllActions()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var suggestions: [String]
        private var shouldOfferCompletion = false
        init(text: Binding<String>, suggestions: [String]) {
            self.text = text
            self.suggestions = suggestions
        }
        func textView(_ textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {
            let partial = (textView.string as NSString).substring(with: charRange)
            return SQLCompletion.candidates(suggestions, matching: partial)
        }
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSStandardKeyBindingResponding.complete(_:)) {
                textView.complete(nil)
                return true
            }
            return false
        }
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let replacementString, !replacementString.isEmpty else {
                // Deleting a wrongly inserted identifier must never reopen the
                // completion popup or reinsert the deleted suffix.
                shouldOfferCompletion = false
                return true
            }
            shouldOfferCompletion = SQLCompletion.shouldOffer(for: replacementString)
            return true
        }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            text.wrappedValue = editor.string
            highlight(editor)
            if let container = editor.enclosingScrollView?.superview as? SQLEditorContainer {
                updateGutter(in: container, text: editor.string)
            }
            let offerCompletion = shouldOfferCompletion
            shouldOfferCompletion = false
            let partial = editor.currentPartialWord
            if offerCompletion, partial.count >= 2, editor.window?.firstResponder === editor {
                DispatchQueue.main.async { [weak editor] in editor?.complete(nil) }
            }
        }
        func highlight(_ editor: NSTextView) {
            let range = editor.selectedRange()
            let source = editor.string as NSString
            let full = NSRange(location: 0, length: source.length)
            let base: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: NSColor.textColor
            ]
            editor.textStorage?.beginEditing()
            editor.textStorage?.setAttributes(base, range: full)
            SQLSyntaxHighlighter.apply(to: editor.textStorage, source: editor.string)
            editor.textStorage?.endEditing()
            editor.setSelectedRange(range)
        }
        func updateGutter(in container: SQLEditorContainer, text: String) {
            container.gutter.needsDisplay = true
        }
    }
}

enum SQLCompletion {
    static func shouldOffer(for replacement: String) -> Bool {
        replacement.count == 1 && replacement.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == "_"
        }
    }

    static func candidates(_ words: [String], matching partial: String) -> [String] {
        let normalized = partial.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return words.sorted() }
        return words.filter { $0.lowercased().hasPrefix(normalized) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

private extension NSTextView {
    var currentPartialWord: String {
        let source = string as NSString
        let cursor = min(selectedRange().location, source.length)
        var start = cursor
        while start > 0 {
            let scalar = UnicodeScalar(source.character(at: start - 1))!
            if CharacterSet.whitespacesAndNewlines.contains(scalar) || ",();=<>".unicodeScalars.contains(scalar) { break }
            start -= 1
        }
        return source.substring(with: NSRange(location: start, length: cursor - start))
    }
}

final class SQLEditorContainer: NSView {
    let gutter = SQLLineNumberGutter()
    private let gutterWidth: CGFloat = 42
    private weak var scroll: NSScrollView?
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(gutter)
    }
    required init(coder: NSCoder) { fatalError("Not implemented") }
    func embed(scroll: NSScrollView) {
        self.scroll = scroll
        gutter.editor = scroll.documentView as? NSTextView
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(redrawGutter), name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        scroll.autoresizingMask = [.width, .height]
        gutter.autoresizingMask = [.height]
        addSubview(scroll)
        needsLayout = true
    }
    override func layout() {
        super.layout()
        gutter.frame = NSRect(x: 0, y: 0, width: gutterWidth - 1, height: bounds.height)
        scroll?.frame = NSRect(x: gutterWidth, y: 0, width: max(0, bounds.width - gutterWidth), height: bounds.height)
    }
    @objc private func redrawGutter() { gutter.needsDisplay = true }
    deinit { NotificationCenter.default.removeObserver(self) }
}

/// Draws each number from the editor's actual text layout instead of maintaining a
/// second text view. This keeps numbers aligned after multiline paste and wrapping.
final class SQLLineNumberGutter: NSView {
    weak var editor: NSTextView?
    private let font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()
        guard let editor, let layoutManager = editor.layoutManager, editor.textContainer != nil else { return }

        let source = editor.string as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
        var characterLocation = 0
        var lineNumber = 1
        while characterLocation <= source.length {
            let range = source.lineRange(for: NSRange(location: characterLocation, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: range.location, length: 0), actualCharacterRange: nil)
            layoutManager.ensureLayout(forCharacterRange: NSRange(location: range.location, length: 0))
            if glyphRange.location != NSNotFound {
                var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil, withoutAdditionalLayout: true)
                lineRect.origin.x += editor.textContainerOrigin.x
                lineRect.origin.y += editor.textContainerOrigin.y
                let gutterRect = editor.convert(lineRect, to: self)
                let number = String(lineNumber) as NSString
                let size = number.size(withAttributes: attributes)
                let point = NSPoint(x: bounds.width - size.width - 8, y: gutterRect.minY + max(0, (gutterRect.height - size.height) / 2))
                number.draw(at: point, withAttributes: attributes)
            }
            if range.upperBound >= source.length { break }
            characterLocation = range.upperBound
            lineNumber += 1
        }
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()
    }
}
