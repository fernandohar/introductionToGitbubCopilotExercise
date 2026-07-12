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
    static let defaultRemoteURL = "https://raw.githubusercontent.com/fernandohar/card-cabana-ios/main/GameCatalog/catalog.json"

    @Published private(set) var games: [GameVariant] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    @Published var remoteCatalogURL: String {
        didSet { UserDefaults.standard.set(remoteCatalogURL, forKey: "remoteCatalogURL") }
    }

    private let cacheURL: URL
    private var bundledGames: [GameVariant] = []

    var variants: [GameVariant] { games }
    var downloadableGames: [GameVariant] { games.filter(\.isDownloadable) }
    var bundledOnlyGames: [GameVariant] { games.filter { $0.source == .bundled } }
    var hasDownloadableGames: Bool { !downloadableGames.isEmpty }

    init() {
        remoteCatalogURL = UserDefaults.standard.string(forKey: "remoteCatalogURL") ?? Self.defaultRemoteURL
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = caches.appendingPathComponent("game-catalog.json")
        loadBundledCatalog()
        loadCachedCatalogIfAvailable()
    }

    func game(id: String) -> GameVariant? {
        games.first { $0.id == id }.map(enrichGame)
    }

    func variant(id: String) -> GameVariant? { game(id: id) }

    func loadBundledCatalog() {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json", subdirectory: "GameCatalog"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(GameCatalog.self, from: data) else {
            bundledGames = [GameVariant.bigTwo]
            games = bundledGames
            return
        }
        bundledGames = catalog.games.map(enrichGame)
        games = bundledGames
    }

    func loadCachedCatalogIfAvailable() {
        guard let data = try? Data(contentsOf: cacheURL),
              let catalog = try? JSONDecoder().decode(GameCatalog.self, from: data),
              !catalog.games.isEmpty else { return }
        games = catalog.games.map(enrichGame)
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
            guard !catalog.games.isEmpty else { throw GameCatalogError.invalidCatalog }
            games = catalog.games.map(enrichGame)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            if let cached = try? Data(contentsOf: cacheURL),
               let catalog = try? JSONDecoder().decode(GameCatalog.self, from: cached) {
                games = catalog.games.map(enrichGame)
                lastError = "Using cached games. \(error.localizedDescription)"
            } else {
                games = bundledGames
                lastError = error.localizedDescription
            }
        }
    }

    /// Merges bundled Springfield card art and full rules for The Simpsons UNO deck.
    private func enrichGame(_ game: GameVariant) -> GameVariant {
        guard game.id == "uno-simpsons" else { return game }
        var enriched = game
        enriched.rules = SimpsonsDeckFaces.rules
        var theme = enriched.sheddingTheme ?? SimpsonsDeckFaces.theme
        theme.deckStyle = "simpsons"
        theme.cardBackEmoji = theme.cardBackEmoji ?? "🍩"
        theme.cardBackLabel = theme.cardBackLabel ?? "Springfield"
        if (theme.faces ?? [:]).count < SimpsonsDeckFaces.all.count {
            theme.faces = SimpsonsDeckFaces.all
        }
        enriched.sheddingTheme = theme
        return enriched
    }
}
