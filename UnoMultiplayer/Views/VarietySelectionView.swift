import SwiftUI

struct VarietySelectionView: View {
    @EnvironmentObject private var app: AppViewModel
    @State private var selectedID: String?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Select UNO")
                .font(.title.bold())

            Text(app.playMode == .singlePlayer ? "Choose which UNO to play" : "Host: pick the game for your room")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(app.catalogService.variants) { variant in
                        variantCard(variant)
                    }
                }
                .padding(.horizontal)
            }

            Button("Continue") {
                if let id = selectedID,
                   let variant = app.catalogService.variant(id: id) {
                    app.selectVariant(variant)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedID == nil)
            .padding()
        }
        .navigationTitle("UNO Varieties")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { app.goHome() }
            }
        }
    }

    private func variantCard(_ variant: UnoVariant) -> some View {
        let isSelected = selectedID == variant.id

        return Button {
            selectedID = variant.id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(variant.icon)
                    .font(.system(size: 36))
                Text(variant.name)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(variant.tagline)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? variant.accentSwiftUIColor : .clear, lineWidth: 3)
            )
            .shadow(color: isSelected ? variant.accentSwiftUIColor.opacity(0.4) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        VarietySelectionView()
            .environmentObject(AppViewModel())
    }
}
