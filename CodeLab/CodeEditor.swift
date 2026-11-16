import SwiftUI
import UIKit

/// 代码输入框。用 UIKit 的 UITextView，因为要关掉一堆「贴心」的自动纠正，
/// 否则打出来的引号会变成中文引号，代码立刻报错。
struct CodeEditor: UIViewRepresentable {
    @Binding var text: String
    var onRun: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textColor = UIColor(white: 0.93, alpha: 1)
        view.tintColor = UIColor(red: 0.35, green: 0.8, blue: 0.55, alpha: 1)
        view.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.spellCheckingType = .no
        view.keyboardType = .asciiCapable
        view.textContainerInset = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        view.inputAccessoryView = context.coordinator.makeToolbar()
        view.text = text
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onRun: onRun)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let text: Binding<String>
        private let onRun: () -> Void
        private weak var editor: UITextView?

        init(text: Binding<String>, onRun: @escaping () -> Void) {
            self.text = text
            self.onRun = onRun
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }

        func makeToolbar() -> UIToolbar {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()

            let symbols = ["{", "}", "(", ")", "[", "]", "\"", "=", ";", "+", "<", ">"]
            let symbolItems = symbols.map { symbol in
                UIBarButtonItem(title: symbol, style: .plain, target: self, action: #selector(insertSymbol(_:)))
            }

            let run = UIBarButtonItem(title: "运行",
                                      style: .done,
                                      target: self,
                                      action: #selector(runTapped))

            let spacer = UIBarButtonItem(systemItem: .flexibleSpace)
            let fixed = UIBarButtonItem(systemItem: .fixedSpace)
            fixed.width = 8

            toolbar.items = symbolItems + [spacer, fixed, run]
            return toolbar
        }

        @objc private func insertSymbol(_ sender: UIBarButtonItem) {
            guard let symbol = sender.title else { return }
            let target = activeEditor()
            let selected = target.selectedRange
            target.textStorage.replaceCharacters(in: selected, with: symbol)
            target.selectedRange = NSRange(location: selected.location + (symbol as NSString).length, length: 0)
            text.wrappedValue = target.text
        }

        @objc private func runTapped() {
            onRun()
        }

        /// 找到正在输入的编辑器（inputAccessoryView 没有直接反查能力，用 responder chain）
        private func activeEditor() -> UITextView {
            if let editor { return editor }
            for window in UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows }) {
                if let found = window.firstResponder as? UITextView {
                    editor = found
                    return found
                }
            }
            return editor ?? UITextView()
        }
    }
}

private extension UIView {
    var firstResponder: UIResponder? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let responder = subview.firstResponder { return responder }
        }
        return nil
    }
}