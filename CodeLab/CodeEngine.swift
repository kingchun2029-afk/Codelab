import SwiftUI
import JavaScriptCore
import Combine

struct LogLine: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
}

struct DrawShape: Identifiable {
    enum Kind {
        case rect, circle
    }

    let id = UUID()
    let kind: Kind
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
    let color: Color
}

/// 负责把用户写的 JS 跑起来，并把 print/console.log 和画图指令带回界面。
@MainActor
final class CodeEngine: ObservableObject {
    /// 画布的逻辑坐标：宽 320 高 200，实际显示时等比缩放
    static let canvasSize = CGSize(width: 320, height: 200)

    @Published private(set) var output: [LogLine] = []
    @Published private(set) var shapes: [DrawShape] = []
    @Published private(set) var running = false

    private var runToken = 0

    func run(_ source: String) {
        // 死循环在 JS 线程上杀不掉，只能提前拦
        if let reason = Self.fatalPattern(source) {
            shapes = []
            output = [LogLine(text: reason, isError: true)]
            return
        }

        output = []
        shapes = []
        running = true
        runToken += 1
        let token = runToken
        let started = Date()

        DispatchQueue.global(qos: .userInitiated).async {
            let error = Self.evaluate(
                source,
                log: { text in
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.runToken == token else { return }
                        self.output.append(LogLine(text: text, isError: false))
                    }
                },
                draw: { shape in
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.runToken == token else { return }
                        self.shapes.append(shape)
                    }
                },
                clear: {
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.runToken == token else { return }
                        self.shapes.removeAll()
                    }
                }
            )

            let elapsed = Date().timeIntervalSince(started)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.runToken == token else { return }
                if let error {
                    self.output.append(LogLine(text: error, isError: true))
                }
                if elapsed > 2 {
                    self.output.append(LogLine(
                        text: "这段跑了 \(String(format: "%.1f", elapsed)) 秒，有点久了。",
                        isError: true
                    ))
                }
                self.running = false
            }
        }
    }

    // MARK: - JS 执行

    private final class ErrorBox {
        var message: String?
        var line: Int = 0
    }

    /// 给用户预先准备好的小函数（bootstrap），插在用户代码前面
    private static let bootstrap = """
    var console = {
      log: function () {
        var parts = [];
        for (var i = 0; i < arguments.length; i++) {
          parts.push(describe(arguments[i]));
        }
        nativeLog(parts.join(" "));
      }
    };
    function describe(value) {
      if (value === null) return "null";
      if (typeof value === "object") {
        try { return JSON.stringify(value); } catch (e) { return String(value); }
      }
      return String(value);
    }
    function print() { console.log.apply(null, arguments); }
    function clear() { nativeClear(); }
    function rect(x, y, w, h, c) {
      nativeRect(Number(x), Number(y), Number(w), Number(h), c === undefined ? "#5ac8fa" : String(c));
    }
    function circle(x, y, r, c) {
      nativeCircle(Number(x), Number(y), Number(r), c === undefined ? "#ffd60a" : String(c));
    }
    """

    private static func evaluate(_ source: String,
                                 log: @escaping (String) -> Void,
                                 draw: @escaping (DrawShape) -> Void,
                                 clear: @escaping () -> Void) -> String? {
        guard let context = JSContext() else {
            return "JavaScript 引擎没起来"
        }

        let box = ErrorBox()

        let logBlock: @convention(block) (String) -> Void = { text in log(text) }
        context.setObject(logBlock, forKeyedSubscript: "nativeLog" as NSString)

        let clearBlock: @convention(block) () -> Void = { clear() }
        context.setObject(clearBlock, forKeyedSubscript: "nativeClear" as NSString)

        let rectBlock: @convention(block) (Double, Double, Double, Double, String) -> Void = { x, y, w, h, c in
            draw(DrawShape(kind: .rect, x: x, y: y, w: w, h: h, color: parseColor(c)))
        }
        context.setObject(rectBlock, forKeyedSubscript: "nativeRect" as NSString)

        let circleBlock: @convention(block) (Double, Double, Double, String) -> Void = { x, y, r, c in
            draw(DrawShape(kind: .circle, x: x, y: y, w: r, h: r, color: parseColor(c)))
        }
        context.setObject(circleBlock, forKeyedSubscript: "nativeCircle" as NSString)

        context.exceptionHandler = { _, exception in
            box.message = exception?.toString() ?? "未知错误"
            if let line = exception?.objectForKeyedSubscript("line"), line.isNumber {
                box.line = Int(line.toInt32())
            }
        }

        _ = context.evaluateScript(bootstrap)
        box.message = nil
        box.line = 0

        _ = context.evaluateScript(source, withSourceURL: URL(string: "你的代码.js"))

        if let message = box.message {
            return box.line > 0 ? "第 \(box.line) 行出错：\(message)" : "出错：\(message)"
        }
        return nil
    }

    private static func parseColor(_ text: String) -> Color {
        var hex = text.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else {
            return Color(red: 0.6, green: 0.6, blue: 0.65)
        }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    private static func fatalPattern(_ source: String) -> String? {
        let patterns = [
            "while\\s*\\(\\s*(true|1)\\s*\\)",
            "for\\s*\\(\\s*;\\s*;\\s*\\)",
        ]
        for pattern in patterns where source.range(of: pattern, options: .regularExpression) != nil {
            return "拦下了：代码里有 while(true) 或 for(;;) 这种永远不停的循环。\n"
                + "JS 跑在单独线程上，这种循环我停不掉，会把一个 CPU 核占死，所以这里不执行。\n"
                + "要重复很多次的话，把条件写成有限的，比如 i < 100000。"
        }
        return nil
    }
}