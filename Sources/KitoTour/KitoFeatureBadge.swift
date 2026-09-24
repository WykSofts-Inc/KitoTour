//
//  KitoFeatureBadge.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// How a feature badge looks.
public enum KitoFeatureBadgeStyle: Equatable, Sendable {
    /// A small pulsing dot.
    case dot
    /// A capsule with text, e.g. "New" or "Beta".
    case label(String)

    /// A capsule reading "New".
    public static let new = KitoFeatureBadgeStyle.label("New")
}

/// When a feature badge counts as seen and disappears.
public enum KitoFeatureBadgeClearing: Sendable {
    /// When the badged view is tapped.
    case onTap
    /// After the badged view has been on screen this long.
    case afterShown(Duration)
    /// Only when you call `KitoFeatureBadge.markSeen(_:)`.
    case manually
}

/// A "New" dot or label. Use it on its own, or through `.kitoFeatureBadge(_:)` to show it until
/// the feature has been seen.
public struct KitoFeatureBadge: View {
    private let style: KitoFeatureBadgeStyle
    private let tint: Color?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ style: KitoFeatureBadgeStyle = .new, tint: Color? = nil) {
        self.style = style
        self.tint = tint
    }

    private var palette: KitoTourPalette { KitoTourPalette(theme: theme, tint: tint ?? theme.colors.danger) }

    public var body: some View {
        switch style {
        case .dot: dot
        case .label(let text): label(text)
        }
    }

    private var dot: some View {
        ZStack {
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    glow(Self.phase(at: context.date))
                }
            }
            Circle()
                .fill(palette.accentGradient)
                .overlay(Circle().stroke(theme.colors.surface, lineWidth: 2))
        }
        .frame(width: 11, height: 11)
        .accessibilityElement()
        .accessibilityLabel("New")
    }

    private func glow(_ phase: Double) -> some View {
        Circle()
            .fill(palette.accent.opacity(0.4 * (1 - phase)))
            .scaleEffect(1 + phase * 1.2)
    }

    static func phase(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(theme.typography.caption.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(palette.onAccent)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(palette.accentGradient))
            .overlay(Capsule().stroke(theme.colors.surface, lineWidth: 1.5))
            .shadow(color: palette.accent.opacity(0.35), radius: 4, y: 2)
            .fixedSize()
    }

    // MARK: Seen

    /// The key a badge's seen flag is stored under.
    public static func seenKey(_ id: String) -> String { "badge.\(id)" }

    /// Hides the badge `id` (for `.manually`), on every screen that shows it.
    public static func markSeen(_ id: String, version: Int = 1, store: KitoSeenStore = .standard) {
        store.markSeen(seenKey(id), version: version)
    }

    /// Shows the badge `id` again.
    public static func reset(_ id: String, store: KitoSeenStore = .standard) {
        store.reset(seenKey(id))
    }

    public static func isNew(_ id: String, version: Int = 1, store: KitoSeenStore = .standard) -> Bool {
        !store.hasSeen(seenKey(id), version: version)
    }
}

public extension View {
    /// Puts a "New" badge on this view's corner until the feature has been seen. Bump `version`
    /// to show the badge again for an updated feature.
    ///
    /// ```swift
    /// Button("Insights", systemImage: "chart.bar.xaxis") { … }
    ///     .kitoFeatureBadge("insights", style: .new)
    /// ```
    func kitoFeatureBadge(
        _ id: String,
        style: KitoFeatureBadgeStyle = .dot,
        version: Int = 1,
        clearsOn clearing: KitoFeatureBadgeClearing = .onTap,
        alignment: Alignment = .topTrailing,
        tint: Color? = nil,
        store: KitoSeenStore = .standard
    ) -> some View {
        modifier(KitoFeatureBadgeModifier(id: id, style: style, version: version, clearing: clearing,
                                          alignment: alignment, tint: tint, store: store))
    }
}

private struct KitoFeatureBadgeModifier: ViewModifier {
    let id: String
    let style: KitoFeatureBadgeStyle
    let version: Int
    let clearing: KitoFeatureBadgeClearing
    let alignment: Alignment
    let tint: Color?
    let store: KitoSeenStore

    /// Mirrors the stored version so every badge with this id updates together.
    @AppStorage private var seenVersion: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(id: String, style: KitoFeatureBadgeStyle, version: Int, clearing: KitoFeatureBadgeClearing,
         alignment: Alignment, tint: Color?, store: KitoSeenStore) {
        self.id = id
        self.style = style
        self.version = version
        self.clearing = clearing
        self.alignment = alignment
        self.tint = tint
        self.store = store
        _seenVersion = AppStorage(wrappedValue: 0, store.storageKey(KitoFeatureBadge.seenKey(id)), store: store.defaults)
    }

    private var isNew: Bool { KitoSeenRules.shouldShow(version: version, lastSeen: seenVersion == 0 ? nil : seenVersion) }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: alignment) { badge }
            .simultaneousGesture(TapGesture().onEnded { clearOnTap() })
            .task(id: isNew) { await clearAfterShown() }
            .animation(KitoTourMotion.pop(reduceMotion), value: isNew)
    }

    @ViewBuilder
    private var badge: some View {
        if isNew {
            KitoFeatureBadge(style, tint: tint)
                .offset(badgeOffset)
                .transition(KitoTourMotion.appear(reduceMotion))
                .allowsHitTesting(false)
        }
    }

    /// Nudges the badge half out of the corner.
    private var badgeOffset: CGSize {
        let size: CGFloat = style == .dot ? 4 : 8
        let x: CGFloat = alignment.horizontal == .leading ? -size : (alignment.horizontal == .trailing ? size : 0)
        let y: CGFloat = alignment.vertical == .top ? -size : (alignment.vertical == .bottom ? size : 0)
        return CGSize(width: x, height: y)
    }

    private func markSeen() {
        store.markSeen(KitoFeatureBadge.seenKey(id), version: version)
        seenVersion = max(seenVersion, version)
    }

    private func clearOnTap() {
        guard isNew, case .onTap = clearing else { return }
        markSeen()
    }

    private func clearAfterShown() async {
        guard isNew, case .afterShown(let delay) = clearing else { return }
        try? await Task.sleep(for: delay)
        guard !Task.isCancelled else { return }
        markSeen()
    }
}
