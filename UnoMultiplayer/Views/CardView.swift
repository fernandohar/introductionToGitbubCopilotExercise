import SwiftUI

struct CardView: View {
    let card: Card
    var activeColor: CardColor?
    var isPlayable: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBackground)
                .frame(width: 72, height: 104)
                .shadow(radius: 2)

            VStack(spacing: 4) {
                Text(card.color.displayName.prefix(1).uppercased())
                    .font(.caption2.bold())
                Text(card.value.displayName)
                    .font(.title3.bold())
            }
            .foregroundStyle(.white)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isPlayable ? Color.yellow : Color.clear, lineWidth: 3)
        )
    }

    private var cardBackground: Color {
        let color = activeColor ?? card.color
        switch color {
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .wild: return .purple
        }
    }
}

struct ColorPickerSheet: View {
    let onSelect: (CardColor) -> Void
    @Environment(\.dismiss) private var dismiss

    private let colors: [CardColor] = [.red, .blue, .green, .yellow]

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose a Color")
                .font(.title2.bold())

            HStack(spacing: 16) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        onSelect(color)
                        dismiss()
                    } label: {
                        Circle()
                            .fill(colorFor(color))
                            .frame(width: 56, height: 56)
                    }
                }
            }
        }
        .padding()
    }

    private func colorFor(_ color: CardColor) -> Color {
        switch color {
        case .red: .red
        case .blue: .blue
        case .green: .green
        case .yellow: .yellow
        case .wild: .purple
        }
    }
}

#Preview {
    CardView(card: Card(color: .red, value: .seven))
}
