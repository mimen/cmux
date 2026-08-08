import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite
struct CCSCategoryProjectionTests {
    @Test
    func decodesVersionedCategoryStatesWithoutReclassifyingRows() throws {
        let data = Data(#"""
        {
          "categoryProjectionVersion": 1,
          "categoryProjectionError": null,
          "rows": [
            {"kind":"session","sessionId":"categorized","category":{"effectiveSlug":"events","storedSlug":"events","compactLabel":"Events","fullLabel":"Events, Booking & Live Production","hex":"#692EC2","source":"manual","manualLock":true,"finding":"stored","registryVersion":"1.0.0"}},
            {"kind":"session","sessionId":"uncategorized","category":{"effectiveSlug":null,"storedSlug":null,"compactLabel":null,"fullLabel":null,"hex":null,"source":null,"manualLock":false,"finding":"missing","registryVersion":"1.0.0"}},
            {"kind":"workspace","workspaceId":"workspace-only"}
          ]
        }
        """#.utf8)

        let snapshot = try CCSCategoryProjectionDecoder().decode(data)

        #expect(snapshot.metadataBySessionID["categorized"] == .category(CCSSessionCategory(
            effectiveSlug: "events",
            storedSlug: "events",
            compactLabel: "Events",
            fullLabel: "Events, Booking & Live Production",
            hex: "#692EC2",
            source: "manual",
            manualLock: true,
            finding: "stored",
            registryVersion: "1.0.0"
        )))
        #expect(snapshot.metadataBySessionID["uncategorized"] == .uncategorized)
        #expect(snapshot.metadataBySessionID["workspace-only"] == nil)
    }

    @Test
    func projectionErrorMarksKnownCCSSessionsUnavailable() throws {
        let data = Data(#"""
        {
          "categoryProjectionVersion": 1,
          "categoryProjectionError": "registry unavailable",
          "rows": [{"kind":"session","sessionId":"known-ccs","category":null}]
        }
        """#.utf8)

        let snapshot = try CCSCategoryProjectionDecoder().decode(data)

        #expect(snapshot.metadataBySessionID["known-ccs"] == .unavailable)
    }

    @Test
    func rejectsUnknownProjectionVersion() {
        let data = Data(#"{"categoryProjectionVersion":2,"categoryProjectionError":null,"rows":[]}"#.utf8)

        #expect(throws: CCSCategoryProjectionDecoder.DecodeError.unsupportedSchema(2)) {
            try CCSCategoryProjectionDecoder().decode(data)
        }
    }

    /// The CCS sidebar server fixes its port at 8787. Pointing anywhere else makes every fetch fail
    /// and renders the whole feature inert, which no injected-loader test would ever notice.
    @Test
    func defaultsToThePortTheSidebarServerBindsTo() {
        let endpoint = CCSCategoryProjectionClient.resolveEndpoint(environment: [:])

        #expect(endpoint.port == 8787)
        #expect(endpoint.host == "127.0.0.1")
        #expect(endpoint.path == "/api/snapshot")
    }

    @Test
    func honoursAnOperatorSuppliedPort() {
        let endpoint = CCSCategoryProjectionClient.resolveEndpoint(
            environment: ["CCS_SIDEBAR_PORT": "9911"]
        )

        #expect(endpoint.port == 9911)
    }

    @Test
    func fallsBackToTheDefaultWhenTheSuppliedPortIsNotANumber() {
        let endpoint = CCSCategoryProjectionClient.resolveEndpoint(
            environment: ["CCS_SIDEBAR_PORT": "not-a-port"]
        )

        #expect(endpoint.port == 8787)
    }
}
