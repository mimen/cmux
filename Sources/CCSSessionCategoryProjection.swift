import Foundation

struct CCSSessionCategory: Codable, Hashable, Sendable {
    let effectiveSlug: String?
    let storedSlug: String?
    let compactLabel: String?
    let fullLabel: String?
    let hex: String?
    let source: String?
    let manualLock: Bool
    let finding: String
    let registryVersion: String
}

enum CCSSessionCategoryMetadata: Hashable, Sendable {
    case absent
    case uncategorized
    case category(CCSSessionCategory)
    case unavailable
}

struct CCSCategoryProjectionSnapshot: Sendable {
    static let supportedSchema = 1

    let metadataBySessionID: [String: CCSSessionCategoryMetadata]

    static let empty = CCSCategoryProjectionSnapshot(metadataBySessionID: [:])
}

struct CCSCategoryProjectionDecoder {
    private struct Envelope: Decodable {
        let categoryProjectionVersion: Int
        let categoryProjectionError: String?
        let rows: [Row]
    }

    private struct Row: Decodable {
        let kind: String
        let sessionId: String?
        let category: CCSSessionCategory?
    }

    enum DecodeError: Error, Equatable {
        case unsupportedSchema(Int)
    }

    func decode(_ data: Data) throws -> CCSCategoryProjectionSnapshot {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.categoryProjectionVersion == CCSCategoryProjectionSnapshot.supportedSchema else {
            throw DecodeError.unsupportedSchema(envelope.categoryProjectionVersion)
        }

        var metadata: [String: CCSSessionCategoryMetadata] = [:]
        for row in envelope.rows where row.kind == "session" {
            guard let sessionID = row.sessionId, !sessionID.isEmpty else { continue }
            if envelope.categoryProjectionError != nil {
                metadata[sessionID] = .unavailable
            } else if let category = row.category {
                metadata[sessionID] = category.effectiveSlug == nil ? .uncategorized : .category(category)
            } else {
                // Projection succeeded but this row lacks its declared category seam.
                // Treat that as unavailable rather than inventing Uncategorized.
                metadata[sessionID] = .unavailable
            }
        }
        return CCSCategoryProjectionSnapshot(metadataBySessionID: metadata)
    }
}

actor CCSCategoryProjectionClient {
    static let shared = CCSCategoryProjectionClient()

    typealias DataLoader = @Sendable (URL) async throws -> Data

    /// Matches `DEFAULT_SIDEBAR_PORT` in the CCS sidebar server, which fixes the port so cmux has a
    /// stable origin to point at. An operator running `ccs sidebar serve --port N` overrides both.
    static let defaultPort = 8787
    /// Resolved from the environment so a test can assert the address without reaching the network,
    /// which is how a wrong port previously shipped past an entirely injected-loader test suite.
    static func resolveEndpoint(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        let port = environment["CCS_SIDEBAR_PORT"].flatMap(Int.init) ?? defaultPort
        return URL(string: "http://127.0.0.1:\(port)/api/snapshot")!
    }
    private static let endpoint: URL = resolveEndpoint()
    private static let scopes = ["active", "completed", "archived"]
    private static let cacheLifetime: TimeInterval = 2.5

    private let dataLoader: DataLoader
    private var cached: (loadedAt: Date, snapshot: CCSCategoryProjectionSnapshot)?

    init(dataLoader: @escaping DataLoader = { url in
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }) {
        self.dataLoader = dataLoader
    }

    func load() async -> CCSCategoryProjectionSnapshot {
        if let cached, Date().timeIntervalSince(cached.loadedAt) < Self.cacheLifetime {
            return cached.snapshot
        }

        do {
            let snapshots = try await withThrowingTaskGroup(of: CCSCategoryProjectionSnapshot.self) { group in
                for scope in Self.scopes {
                    group.addTask { [dataLoader] in
                        var components = URLComponents(url: Self.endpoint, resolvingAgainstBaseURL: false)!
                        components.queryItems = [
                            URLQueryItem(name: "scope", value: scope),
                            URLQueryItem(name: "limit", value: "200"),
                        ]
                        let data = try await dataLoader(components.url!)
                        return try CCSCategoryProjectionDecoder().decode(data)
                    }
                }
                var values: [CCSCategoryProjectionSnapshot] = []
                for try await value in group {
                    values.append(value)
                }
                return values
            }
            let merged = snapshots.reduce(into: [String: CCSSessionCategoryMetadata]()) { result, snapshot in
                result.merge(snapshot.metadataBySessionID) { current, _ in current }
            }
            let snapshot = CCSCategoryProjectionSnapshot(metadataBySessionID: merged)
            cached = (Date(), snapshot)
            return snapshot
        } catch {
            // No CCS row identity can be asserted when its public projection is unreachable.
            // Preserve a prior identity set if available, marking those rows unavailable.
            let unavailable = cached?.snapshot.metadataBySessionID.keys.reduce(
                into: [String: CCSSessionCategoryMetadata](),
                { $0[$1] = .unavailable }
            ) ?? [:]
            return CCSCategoryProjectionSnapshot(metadataBySessionID: unavailable)
        }
    }
}

struct CCSSessionCategoryDecorator: Sendable {
    typealias ProjectionLoader = @Sendable () async -> CCSCategoryProjectionSnapshot

    private let projectionLoader: ProjectionLoader

    init(projectionLoader: @escaping ProjectionLoader = {
        await CCSCategoryProjectionClient.shared.load()
    }) {
        self.projectionLoader = projectionLoader
    }

    func decorate(_ entries: [SessionEntry]) async -> [SessionEntry] {
        let projection = await projectionLoader()
        return entries.map { entry in
            entry.withCCSCategoryMetadata(
                projection.metadataBySessionID[entry.sessionId] ?? .absent
            )
        }
    }
}
