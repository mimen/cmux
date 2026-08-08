import AppKit
import SwiftUI

struct SessionCategoryRenderData: Hashable {
    enum Style: Hashable {
        case category
        case uncategorized
        case unavailable
    }

    let style: Style
    let label: String
    let helpText: String
    let accessibilityLabel: String
    let color: NSColor?

    static func make(from metadata: CCSSessionCategoryMetadata) -> SessionCategoryRenderData? {
        switch metadata {
        case .absent:
            return nil
        case .uncategorized:
            let label = String(localized: "sessionIndex.category.uncategorized", defaultValue: "Uncategorized")
            return SessionCategoryRenderData(
                style: .uncategorized,
                label: label,
                helpText: label,
                accessibilityLabel: label,
                color: nil
            )
        case .unavailable:
            let label = String(localized: "sessionIndex.category.unavailable", defaultValue: "Category unavailable")
            return SessionCategoryRenderData(
                style: .unavailable,
                label: label,
                helpText: String(localized: "sessionIndex.category.unavailable.help", defaultValue: "CCS category metadata is unavailable."),
                accessibilityLabel: label,
                color: nil
            )
        case .category(let category):
            guard let compactLabel = normalized(category.compactLabel),
                  let fullLabel = normalized(category.fullLabel),
                  let hex = normalized(category.hex),
                  let color = NSColor(ccsHex: hex) else {
                let label = String(localized: "sessionIndex.category.unavailable", defaultValue: "Category unavailable")
                return SessionCategoryRenderData(
                    style: .unavailable,
                    label: label,
                    helpText: String(localized: "sessionIndex.category.unavailable.help", defaultValue: "CCS category metadata is unavailable."),
                    accessibilityLabel: label,
                    color: nil
                )
            }
            return SessionCategoryRenderData(
                style: .category,
                label: compactLabel,
                helpText: String(
                    format: String(localized: "sessionIndex.category.help.format", defaultValue: "%1$@ (%2$@)"),
                    fullLabel,
                    hex
                ),
                accessibilityLabel: String(
                    format: String(localized: "sessionIndex.category.accessibility.format", defaultValue: "Category: %1$@, color %2$@"),
                    fullLabel,
                    hex
                ),
                color: color
            )
        }
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

private extension NSColor {
    convenience init?(ccsHex: String) {
        let value = ccsHex.hasPrefix("#") ? String(ccsHex.dropFirst()) : ccsHex
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct SessionCategoryIndicator: View, Equatable {
    let data: SessionCategoryRenderData

    var body: some View {
        HStack(spacing: 4) {
            indicator
            Text(data.label)
                .cmuxFont(size: 10, weight: .medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .help(data.helpText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(data.accessibilityLabel)
    }

    @ViewBuilder
    private var indicator: some View {
        switch data.style {
        case .category:
            Circle()
                .fill(Color(nsColor: data.color ?? .clear))
                .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 0.5))
                .frame(width: 8, height: 8)
        case .uncategorized:
            Circle()
                .stroke(Color.secondary.opacity(0.7), lineWidth: 1)
                .frame(width: 8, height: 8)
        case .unavailable:
            Image(systemName: "exclamationmark.triangle.fill")
                .cmuxFont(size: 9)
                .foregroundColor(.orange)
        }
    }
}
