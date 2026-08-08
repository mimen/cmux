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
}
