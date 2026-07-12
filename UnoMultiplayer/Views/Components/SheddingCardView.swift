import SwiftUI

struct SheddingCardView: View {
    let card: SheddingCard
    var theme: SheddingTheme?
    var isPlayable: Bool = true

    private var resolvedTheme: SheddingTheme? { theme }
    private var isSimpsons: Bool { resolvedTheme?.isSimpsonsDeck == true }

    var body: some View {
        Group {
            if isSimpsons {
                simpsonsCard
            } else {
                standardCard
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: isSimpsons ? 12 : 10)
                .stroke(isPlayable ? AppTheme.accent : .clear, lineWidth: 2.5)
        )
    }

    // MARK: - Simpsons styled card (oval portrait, corner symbols)

    private var simpsonsCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .frame(width: 64, height: 92)
                .overlay(patternOverlay)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            if card.isWild {
                wildColorRing
            }

            // Corner values (UNO layout)
            VStack {
                HStack {
                    cornerLabel(rotation: 0)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    cornerLabel(rotation: 180)
                }
            }
            .padding(5)
            .frame(width: 64, height: 92)

            // White oval portrait
            Ellipse()
                .fill(Color.white)
                .frame(width: 40, height: 52)
                .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                .overlay(portraitContent)
        }
    }

    private var portraitContent: some View {
        VStack(spacing: 2) {
            if let face = resolvedTheme?.face(for: card) {
                Text(face.emoji)
                    .font(.system(size: 24))
                Text(face.name)
                    .font(.system(size: 6, weight: .semibold))
                    .foregroundStyle(Color(hex: "#333333"))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .frame(width: 36)
            } else {
                Text(card.value.displayName)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(backgroundColor)
            }
        }
    }

    private func cornerLabel(rotation: Double) -> some View {
        Text(card.value.displayName)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 1)
            .rotationEffect(.degrees(rotation))
    }

    private var wildColorRing: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [.red, .yellow, .green, .blue, .red],
                    center: .center
                ),
                lineWidth: 3
            )
            .frame(width: 54, height: 54)
            .opacity(0.7)
    }

    // MARK: - Standard card

    private var standardCard: some View {
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

                if let face = resolvedTheme?.face(for: card) {
                    Text(face.emoji).font(.system(size: 22))
                    Text(face.name)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .padding(4)
        }
    }

    private var backgroundColor: Color {
        Color(hex: resolvedTheme?.style(for: card.color).color ?? defaultHex(for: card.color))
    }

    @ViewBuilder
    private var patternOverlay: some View {
        let pattern = resolvedTheme?.style(for: card.color).pattern ?? "solid"
        switch pattern {
        case "dots":
            Canvas { context, size in
                for x in stride(from: 4, to: size.width, by: 8) {
                    for y in stride(from: 4, to: size.height, by: 8) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)), with: .color(.white.opacity(0.22)))
                    }
                }
            }
        case "checkered":
            Canvas { context, size in
                let cell: CGFloat = 8
                for row in 0 ..< Int(size.height / cell) {
                    for col in 0 ..< Int(size.width / cell) where (row + col).isMultiple(of: 2) {
                        let rect = CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                        context.fill(Path(rect), with: .color(.white.opacity(0.16)))
                    }
                }
            }
        case "stripes":
            Canvas { context, size in
                for offset in stride(from: -size.height, to: size.width, by: 8) {
                    var path = Path()
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                    context.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 3)
                }
            }
        case "diamonds":
            Canvas { context, size in
                for x in stride(from: 6, to: size.width, by: 11) {
                    for y in stride(from: 6, to: size.height, by: 11) {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y - 3))
                        path.addLine(to: CGPoint(x: x + 3, y: y))
                        path.addLine(to: CGPoint(x: x, y: y + 3))
                        path.addLine(to: CGPoint(x: x - 3, y: y))
                        path.closeSubpath()
                        context.fill(path, with: .color(.white.opacity(0.2)))
                    }
                }
            }
        case "characters":
            ZStack {
                ForEach(0 ..< 6, id: \.self) { index in
                    Text(["😄", "🍩", "🍺", "🎷", "🐶", "💰"][index])
                        .font(.system(size: 14))
                        .opacity(0.12)
                        .offset(
                            x: CGFloat([-18, 16, -8, 20, 0, -20][index]),
                            y: CGFloat([-24, -10, 18, 22, 30, 8][index])
                        )
                }
            }
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

struct SheddingCardBackView: View {
    var theme: SheddingTheme?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: theme?.cardBack ?? "#4A6FA5"))
                .frame(width: 64, height: 92)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            if theme?.isSimpsonsDeck == true {
                VStack(spacing: 4) {
                    Text(theme?.cardBackEmoji ?? "🍩")
                        .font(.system(size: 28))
                    Text(theme?.cardBackLabel ?? "Springfield")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color(hex: "#D4522A"))
                    Text("UNO")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color(hex: "#E53935"))
                }
            } else {
                Image(systemName: "suit.heart.fill")
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

struct SheddingColorPickerSheet: View {
    var theme: SheddingTheme?
    let onSelect: (SheddingColor) -> Void
    @Environment(\.dismiss) private var dismiss

    private let colors: [SheddingColor] = [.red, .blue, .green, .yellow]

    var body: some View {
        VStack(spacing: 20) {
            if theme?.isSimpsonsDeck == true {
                Text("🍩 Pick a Springfield Colour")
                    .font(.title3.bold())
            } else {
                Text("Choose a Colour")
                    .font(.title2.bold())
            }

            HStack(spacing: 14) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        onSelect(color)
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hex: theme?.style(for: color).color ?? "#888888"))
                                .frame(width: 52, height: 72)
                                .overlay(patternPreview(for: color))
                            Text(color.displayName)
                                .font(.caption2.bold())
                        }
                    }
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func patternPreview(for color: SheddingColor) -> some View {
        let pattern = theme?.style(for: color).pattern ?? "solid"
        if pattern == "dots" {
            Image(systemName: "circle.grid.3x3.fill").foregroundStyle(.white.opacity(0.4))
        } else if pattern == "checkered" {
            Image(systemName: "square.grid.2x2.fill").foregroundStyle(.white.opacity(0.4))
        } else if pattern == "stripes" {
            Image(systemName: "line.diagonal").foregroundStyle(.white.opacity(0.4))
        } else {
            EmptyView()
        }
    }
}

#Preview("Simpsons cards") {
    HStack(spacing: 8) {
        SheddingCardView(
            card: SheddingCard(color: .blue, value: .skip),
            theme: SimpsonsDeckFaces.theme
        )
        SheddingCardView(
            card: SheddingCard(color: .wild, value: .wild),
            theme: SimpsonsDeckFaces.theme
        )
        SheddingCardBackView(theme: SimpsonsDeckFaces.theme)
    }
    .padding()
}
