import SwiftUI

struct SheddingCardView: View {
    let card: SheddingCard
    var theme: SheddingTheme?
    var isPlayable: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
                .frame(width: 56, height: 80)
                .overlay(patternOverlay)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)

            VStack(spacing: 2) {
                Text(card.value.displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let face = theme?.face(for: card) {
                    Text(face.emoji)
                        .font(.system(size: 22))
                    Text(face.name)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else {
                    Text(card.color.displayName.prefix(1).uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isPlayable ? AppTheme.accent : .clear, lineWidth: 2.5)
        )
    }

    private var backgroundColor: Color {
        let hex = theme?.style(for: card.color).color ?? defaultHex(for: card.color)
        return Color(hex: hex)
    }

    @ViewBuilder
    private var patternOverlay: some View {
        let pattern = theme?.style(for: card.color).pattern ?? "solid"
        switch pattern {
        case "dots":
            Canvas { context, size in
                for x in stride(from: 4, to: size.width, by: 8) {
                    for y in stride(from: 4, to: size.height, by: 8) {
                        let rect = CGRect(x: x, y: y, width: 3, height: 3)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.2)))
                    }
                }
            }
        case "checkered":
            Canvas { context, size in
                let cell: CGFloat = 8
                for row in 0 ..< Int(size.height / cell) {
                    for col in 0 ..< Int(size.width / cell) {
                        if (row + col).isMultiple(of: 2) {
                            let rect = CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                            context.fill(Path(rect), with: .color(.white.opacity(0.15)))
                        }
                    }
                }
            }
        case "stripes":
            Canvas { context, size in
                for offset in stride(from: -size.height, to: size.width, by: 10) {
                    var path = Path()
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                    context.stroke(path, with: .color(.white.opacity(0.15)), lineWidth: 4)
                }
            }
        case "diamonds":
            Canvas { context, size in
                for x in stride(from: 6, to: size.width, by: 12) {
                    for y in stride(from: 6, to: size.height, by: 12) {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y - 3))
                        path.addLine(to: CGPoint(x: x + 3, y: y))
                        path.addLine(to: CGPoint(x: x, y: y + 3))
                        path.addLine(to: CGPoint(x: x - 3, y: y))
                        path.closeSubpath()
                        context.fill(path, with: .color(.white.opacity(0.18)))
                    }
                }
            }
        case "characters":
            Text("✨")
                .font(.system(size: 40))
                .opacity(0.15)
        default:
            EmptyView()
        }
    }

    private func defaultHex(for color: SheddingColor) -> String {
        switch color {
        case .red: "#E53935"
        case .blue: "#1E88E5"
        case .green: "#43A047"
        case .yellow: "#FDD835"
        case .wild: "#212121"
        }
    }
}

struct SheddingColorPickerSheet: View {
    let onSelect: (SheddingColor) -> Void
    @Environment(\.dismiss) private var dismiss

    private let colors: [SheddingColor] = [.red, .blue, .green, .yellow]

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose a Colour")
                .font(.title2.bold())
            HStack(spacing: 16) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        onSelect(color)
                        dismiss()
                    } label: {
                        Circle()
                            .fill(Color(hex: defaultHex(for: color)))
                            .frame(width: 56, height: 56)
                    }
                }
            }
        }
        .padding()
    }

    private func defaultHex(for color: SheddingColor) -> String {
        switch color {
        case .red: "#E53935"
        case .blue: "#1E88E5"
        case .green: "#43A047"
        case .yellow: "#FDD835"
        case .wild: "#212121"
        }
    }
}
