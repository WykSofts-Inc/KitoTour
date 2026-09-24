//
//  KitoWhatsNew.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// One row on the What's New sheet.
public struct KitoWhatsNewFeature: Identifiable, Equatable {
    public var id: String { title }
    public var systemImage: String
    public var title: String
    public var message: String
    /// The icon's colour. `nil` uses the sheet's tint.
    public var tint: Color?

    public init(_ title: String, message: String, systemImage: String, tint: Color? = nil) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
    }
}

/// The content of a What's New sheet for one release.
///
/// ```swift
/// let whatsNew = KitoWhatsNew(version: "2.4", title: "What's new in Pesa", features: [
///     KitoWhatsNewFeature("Split bills", message: "Share a bill with friends in two taps.",
///                         systemImage: "person.2.fill", tint: .orange),
/// ])
/// ```
public struct KitoWhatsNew: Equatable {
    /// A dotted version, compared number by number: "2.10" is newer than "2.9".
    public var version: String
    public var title: String
    public var subtitle: String?
    public var features: [KitoWhatsNewFeature]
    public var buttonTitle: String
    /// Groups releases of one app (or one area of it) under one "last seen" record.
    public var id: String

    public init(version: String, title: String = "What's New", subtitle: String? = nil,
                features: [KitoWhatsNewFeature], buttonTitle: String = "Continue", id: String = "app") {
        self.version = version
        self.title = title
        self.subtitle = subtitle
        self.features = features
        self.buttonTitle = buttonTitle
        self.id = id
    }

    public var seenKey: String { "whatsnew.\(id)" }

    /// Whether this release is newer than the last one shown.
    public func shouldShow(store: KitoSeenStore = .standard) -> Bool {
        !store.hasSeen(seenKey, release: version)
    }

    public func markSeen(store: KitoSeenStore = .standard) {
        store.markSeen(seenKey, release: version)
    }
}

/// A What's New sheet: a version pill and title, feature rows that arrive one after another, and a
/// Continue button.
public struct KitoWhatsNewView: View {
    private let whatsNew: KitoWhatsNew
    private let tint: Color?
    private let onContinue: () -> Void

    @State private var shown = false
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ whatsNew: KitoWhatsNew, tint: Color? = nil, onContinue: @escaping () -> Void) {
        self.whatsNew = whatsNew
        self.tint = tint
        self.onContinue = onContinue
    }

    private var palette: KitoTourPalette { KitoTourPalette(theme: theme, tint: tint) }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    header
                    VStack(alignment: .leading, spacing: theme.spacing.xl) {
                        ForEach(Array(whatsNew.features.enumerated()), id: \.element.id) { index, feature in
                            KitoWhatsNewRow(feature: feature, palette: palette)
                                .opacity(shown ? 1 : 0)
                                .offset(y: shown || reduceMotion ? 0 : 18)
                                .animation(rowAnimation(index), value: shown)
                        }
                    }
                }
                .padding(.horizontal, theme.spacing.xl)
                .padding(.top, theme.spacing.xxl + theme.spacing.lg)
                .padding(.bottom, theme.spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            continueButton
        }
        .background(theme.colors.background.ignoresSafeArea())
        .onAppear { shown = true }
    }

    private func rowAnimation(_ index: Int) -> Animation {
        KitoTourMotion.pop(reduceMotion).delay(reduceMotion ? 0 : 0.15 + Double(index) * 0.08)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Version \(whatsNew.version)")
                .font(theme.typography.caption.weight(.bold))
                .foregroundStyle(palette.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(palette.accent.opacity(0.12)))
            Text(whatsNew.title)
                .font(theme.typography.displayLarge)
                .foregroundStyle(theme.colors.onBackground)
                .accessibilityAddTraits(.isHeader)
            if let subtitle = whatsNew.subtitle {
                Text(subtitle)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.onBackground.opacity(0.66))
            }
        }
        .scaleEffect(shown || reduceMotion ? 1 : 0.96, anchor: .topLeading)
        .opacity(shown ? 1 : 0)
        .animation(KitoTourMotion.pop(reduceMotion), value: shown)
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Text(whatsNew.buttonTitle)
                .font(theme.typography.button)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(KitoWhatsNewButtonStyle(palette: palette))
        .padding(.horizontal, theme.spacing.xl)
        .padding(.top, theme.spacing.md)
        .padding(.bottom, theme.spacing.lg)
        .background(theme.colors.background)
    }
}

private struct KitoWhatsNewRow: View {
    let feature: KitoWhatsNewFeature
    let palette: KitoTourPalette

    private var theme: KitoTheme { palette.theme }
    private var colour: Color { feature.tint ?? palette.accent }

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.lg) {
            Image(systemName: feature.systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colour.gradient))
                .shadow(color: colour.opacity(0.35), radius: 8, y: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(feature.title)
                    .font(theme.typography.bodyEmphasized.weight(.semibold))
                    .foregroundStyle(theme.colors.onBackground)
                Text(feature.message)
                    .font(theme.typography.label)
                    .foregroundStyle(theme.colors.onBackground.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct KitoWhatsNewButtonStyle: ButtonStyle {
    let palette: KitoTourPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(palette.onAccent)
            .frame(minHeight: 54)
            .background(Capsule().fill(palette.accentGradient))
            .shadow(color: palette.accent.opacity(0.3), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

public extension View {
    /// Presents `whatsNew` as a sheet while `isPresented` is true, and marks its version seen
    /// when it's dismissed.
    func kitoWhatsNew(_ whatsNew: KitoWhatsNew, isPresented: Binding<Bool>, tint: Color? = nil,
                      store: KitoSeenStore = .standard) -> some View {
        sheet(isPresented: isPresented, onDismiss: { whatsNew.markSeen(store: store) }) {
            KitoWhatsNewView(whatsNew, tint: tint) { isPresented.wrappedValue = false }
                .presentationDragIndicator(.visible)
        }
    }

    /// Presents `whatsNew` once per version: when this view appears and the version is newer than
    /// the last one seen.
    ///
    /// ```swift
    /// ContentView()
    ///     .kitoWhatsNew(KitoWhatsNew(version: "2.4", features: features))
    /// ```
    func kitoWhatsNew(_ whatsNew: KitoWhatsNew, tint: Color? = nil, store: KitoSeenStore = .standard) -> some View {
        modifier(KitoWhatsNewOnceModifier(whatsNew: whatsNew, tint: tint, store: store))
    }
}

private struct KitoWhatsNewOnceModifier: ViewModifier {
    let whatsNew: KitoWhatsNew
    let tint: Color?
    let store: KitoSeenStore

    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .kitoWhatsNew(whatsNew, isPresented: $isPresented, tint: tint, store: store)
            .task(id: whatsNew.version) {
                try? await Task.sleep(for: .milliseconds(400))
                if whatsNew.shouldShow(store: store) { isPresented = true }
            }
    }
}
