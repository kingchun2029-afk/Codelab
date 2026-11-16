import SwiftUI

/// 把 rect / circle 这些指令画出来。逻辑坐标固定 320×200，按显示区域等比缩放。
struct ShapeCanvas: View {
    let shapes: [DrawShape]

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let logical = CodeEngine.canvasSize
                let scale = min(size.width / logical.width, size.height / logical.height)
                let dx = (size.width - logical.width * scale) / 2
                let dy = (size.height - logical.height * scale) / 2

                context.translateBy(x: dx, y: dy)
                context.scaleBy(x: scale, y: scale)

                for shape in shapes {
                    switch shape.kind {
                    case .rect:
                        let rect = CGRect(x: shape.x, y: shape.y, width: shape.w, height: shape.h)
                        context.fill(Path(roundedRect: rect, cornerRadius: 2),
                                     with: .color(shape.color))
                    case .circle:
                        let r = shape.w
                        let rect = CGRect(x: shape.x - r, y: shape.y - r, width: r * 2, height: r * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(shape.color))
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                Text("320 × 200")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
        }
        .background(Color.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}