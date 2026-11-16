import SwiftUI

struct ContentView: View {
    @StateObject private var engine = CodeEngine()
    @State private var code = UserDefaults.standard.string(forKey: "codelab.lastCode") ?? Lessons.welcome.code
    @State private var panel = 0
    @State private var note: String?

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            CodeEditor(text: $code, onRun: run)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().overlay(Color.white.opacity(0.08))

            panelView
                .frame(height: 220)
        }
        .background(Color(red: 0.07, green: 0.08, blue: 0.1).ignoresSafeArea())
        .onChange(of: code) { _, value in
            UserDefaults.standard.set(value, forKey: "codelab.lastCode")
        }
        .onChange(of: engine.shapes.count) { _, count in
            // 一画东西就自动切到画面，不然看起来像没反应
            if count > 0, !ProcessInfo.processInfo.arguments.contains("-keep-output") { panel = 1 }
        }
        #if DEBUG
        .task {
            // 开发用：带 -autorun 启动就直接跑一遍当前编辑区的内容
            if ProcessInfo.processInfo.arguments.contains("-autorun"), !code.isEmpty {
                run()
            }
        }
        #endif
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("代码实验")
                    .font(.headline)
                Text(engine.running ? "运行中…" : "写 JS，点运行，看现象")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                ForEach(Lessons.all) { lesson in
                    Button(lesson.title) { load(lesson) }
                }
                Divider()
                Button("清空编辑区", role: .destructive) {
                    code = ""
                    note = nil
                }
            } label: {
                Label("例子", systemImage: "book")
                    .font(.footnote)
            }

            Button(action: run) {
                Label(engine.running ? "运行中" : "运行", systemImage: "play.fill")
                    .font(.footnote.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.24, green: 0.62, blue: 0.44))
            .disabled(engine.running)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var panelView: some View {
        VStack(spacing: 0) {
            Picker("", selection: $panel) {
                Text("输出").tag(0)
                Text("画面").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if panel == 0 {
                console
            } else {
                ShapeCanvas(shapes: engine.shapes)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
    }

    private var console: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if engine.output.isEmpty {
                        Text("print 出来的东西会出现在这里")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(engine.output) { line in
                        Text(line.text)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(line.isError
                                             ? Color(red: 1, green: 0.45, blue: 0.4)
                                             : Color(white: 0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .onChange(of: engine.output.count) { _, _ in
                if let last = engine.output.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func load(_ lesson: Lesson) {
        code = lesson.code
        note = "\(lesson.title)：\(lesson.note)"
        panel = 0
    }

    private func run() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        panel = 0
        engine.run(code)
    }
}