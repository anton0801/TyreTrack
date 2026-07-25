//
//  SignaturePad.swift
//  TyreTrack
//
//  Finger-drawn signature capture — pure SwiftUI Path + DragGesture (iOS 14 safe).
//

import SwiftUI

struct SignaturePad: View {
    @Binding var pngData: Data?
    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                    .fill(TT.surfaceSunken)
                RoundedRectangle(cornerRadius: TTShape.well, style: .continuous)
                    .stroke(TT.hairline, lineWidth: 1)

                // Baseline
                GeometryReader { geo in
                    Path { p in
                        let y = geo.size.height * 0.72
                        p.move(to: CGPoint(x: 16, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width - 16, y: y))
                    }
                    .stroke(TT.hairlineSoft, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                SignatureShape(strokes: strokes, current: current)
                    .stroke(TT.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                if strokes.isEmpty && current.isEmpty {
                    Text("SIGN HERE")
                        .font(.ttLabel(.caption2))
                        .kerning(1.6)
                        .foregroundColor(TT.textTertiary)
                }
            }
            .frame(height: 160)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in current.append(value.location) }
                    .onEnded { _ in
                        if !current.isEmpty { strokes.append(current) }
                        current = []
                        render()
                    }
            )

            Button(action: clear) {
                Text("CLEAR SIGNATURE")
                    .font(.ttLabel(.caption2))
                    .kerning(1.3)
                    .foregroundColor(TT.steelLight)
            }
        }
    }

    private func clear() {
        strokes = []
        current = []
        pngData = nil
    }

    private func render() {
        let size = CGSize(width: 320, height: 160)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor(hex: 0x0C0E11).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(hex: 0xE9A231).setStroke()
            let path = UIBezierPath()
            path.lineWidth = 2.5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            for stroke in strokes {
                guard let first = stroke.first else { continue }
                path.move(to: first)
                for pt in stroke.dropFirst() { path.addLine(to: pt) }
            }
            path.stroke()
        }
        pngData = img.pngData()
    }
}

private struct SignatureShape: Shape {
    var strokes: [[CGPoint]]
    var current: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for stroke in strokes { addStroke(stroke, to: &path) }
        addStroke(current, to: &path)
        return path
    }

    private func addStroke(_ pts: [CGPoint], to path: inout Path) {
        guard let first = pts.first else { return }
        path.move(to: first)
        for pt in pts.dropFirst() { path.addLine(to: pt) }
    }
}
