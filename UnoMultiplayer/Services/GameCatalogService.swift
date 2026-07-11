import Foundation

enum GameCatalogError: LocalizedError {
    case bundledCatalogMissing
    case downloadFailed
    case invalidCatalog

    var errorDescription: String? {
        switch self {
        case .bundledCatalogMissing: "Built-in game catalog is missing."
        case .downloadFailed: "Could not download the latest games."
        case .invalidCatalog: "Downloaded catalog is invalid."
        }
    }
}

@MainActor
final class GameCatalogService: ObservableObject {
    static let defaultRemoteURL = "https://raw.githubusercontent.com/fernandohar/uno-multiplayer-ios/main/GameCatalog/catalog.json"

    @Published private(set) var variants: [UnoVariant] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    @Published var remoteCatalogURL: String {
        didSet { UserDefaults.standard.set(remoteCatalogURL, forKey: "remoteCatalogURL") }
    }

    private let cacheURL: URL

    init() {
        remoteCatalogURL = UserDefaults.standard.string(forKey: "remoteCatalogURL") ?? Self.defaultRemoteURL
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = caches.appendingPathComponent("game-catalog.json")
        loadBundledCatalog()
    }

    func variant(id: String) -> UnoVariant? {
        variants.first { $0.id == id }
    }

    func loadBundledCatalog() {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json", subdirectory: "GameCatalog"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(GameCatalog.self, from: data) else {
            variants = [UnoVariant.classic]
            return
        }
        variants = catalog.variants
    }

    func fetchLatestGames() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        guard let url = URL(string: remoteCatalogURL) else {
            lastError = GameCatalogError.downloadFailed.localizedDescription
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                throw GameCatalogError.downloadFailed
            }
            let catalog = try JSONDecoder().decode(GameCatalog.self, from: data)
            guard !catalog.variants.isEmpty else { throw GameCatalogError.invalidCatalog }
            variants = catalog.variants
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            if let cached = try? Data(contentsOf: cacheURL),
               let catalog = try? JSONDecoder().decode(GameCatalog.self, from: cached) {
                variants = catalog.variants
                lastError = "Using cached games. \(error.localizedDescription)"
            } else {
                lastError = error.localizedDescription
            }
        }
    }
}
