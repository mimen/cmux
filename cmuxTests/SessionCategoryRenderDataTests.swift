import AppKit
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite
struct SessionCategoryRenderDataTests {
    @Test
    func absentMetadataRendersNothing() {
        #expect(SessionCategoryRenderData.make(from: .absent) == nil)
    }

    @Test
    func categorizedMetadataPreservesExactProjectionColorAndLabels() throws {
        let data = try #require(SessionCategoryRenderData.make(from: .category(CCSSessionCategory(
            effectiveSlug: "events",
            storedSlug: "events",
            compactLabel: "Events",
            fullLabel: "Events, Booking & Live Production",
            hex: "#692EC2",
            source: "manual",
            manualLock: true,
            finding: "stored",
            registryVersion: "1.0.0"
        ))))

        #expect(data.style == .category)
        #expect(data.label == "Events")
        #expect(data.helpText.contains("Events, Booking & Live Production"))
        #expect(data.helpText.contains("#692EC2"))
        #expect(data.accessibilityLabel.contains("#692EC2"))

        let color = try #require(data.color?.usingColorSpace(.sRGB))
        #expect(abs(color.redComponent - (105.0 / 255.0)) < 0.001)
        #expect(abs(color.greenComponent - (46.0 / 255.0)) < 0.001)
        #expect(abs(color.blueComponent - (194.0 / 255.0)) < 0.001)
    }

    @Test
    func uncategorizedAndUnavailableRemainDistinctTextStates() throws {
        let uncategorized = try #require(SessionCategoryRenderData.make(from: .uncategorized))
        let unavailable = try #require(SessionCategoryRenderData.make(from: .unavailable))

        #expect(uncategorized.style == .uncategorized)
        #expect(unavailable.style == .unavailable)
        #expect(uncategorized.label != unavailable.label)
        #expect(uncategorized.color == nil)
        #expect(unavailable.color == nil)
    }

    @Test
    func malformedCategoryProjectionFailsClosedAsUnavailable() throws {
        let data = try #require(SessionCategoryRenderData.make(from: .category(CCSSessionCategory(
            effectiveSlug: "events",
            storedSlug: "events",
            compactLabel: "Events",
            fullLabel: "Events, Booking & Live Production",
            hex: "not-a-color",
            source: "manual",
            manualLock: true,
            finding: "stored",
            registryVersion: "1.0.0"
        ))))

        #expect(data.style == .unavailable)
    }
}
