import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite
struct CCSSessionCategoryDecoratorTests {
    @Test
    func decoratesOnlyEntriesPresentInCCSProjection() async {
        let category = CCSSessionCategory(
            effectiveSlug: "events",
            storedSlug: "events",
            compactLabel: "Events",
            fullLabel: "Events, Booking & Live Production",
            hex: "#692EC2",
            source: "manual",
            manualLock: true,
            finding: "stored",
            registryVersion: "1.0.0"
        )
        let decorator = CCSSessionCategoryDecorator {
            CCSCategoryProjectionSnapshot(metadataBySessionID: [
                "ccs-categorized": .category(category),
                "ccs-uncategorized": .uncategorized,
                "ccs-error": .unavailable,
            ])
        }
        let entries = [
            makeEntry(sessionID: "ccs-categorized"),
            makeEntry(sessionID: "ccs-uncategorized"),
            makeEntry(sessionID: "ccs-error"),
            makeEntry(sessionID: "ordinary-claude"),
        ]

        let decorated = await decorator.decorate(entries)

        #expect(decorated.map(\.ccsCategoryMetadata) == [
            .category(category),
            .uncategorized,
            .unavailable,
            .absent,
        ])
        #expect(decorated.map(\.id) == entries.map(\.id))
        #expect(decorated.map(\.sessionId) == entries.map(\.sessionId))
    }

    private func makeEntry(sessionID: String) -> SessionEntry {
        SessionEntry(
            id: sessionID,
            agent: .claude,
            sessionId: sessionID,
            title: sessionID,
            cwd: "/tmp",
            gitBranch: nil,
            pullRequest: nil,
            modified: .distantPast,
            fileURL: nil,
            specifics: .claude(model: nil, permissionMode: nil, configDirectoryForResume: nil)
        )
    }
}
