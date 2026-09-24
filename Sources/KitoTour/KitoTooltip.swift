//
//  KitoTooltip.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import UIKit
import KitoCore

/// The area tooltips stay inside, in global coordinates. Set by `.kitoTooltipBounds()`.
private struct KitoTooltipBoundsKey: EnvironmentKey {
    static let defaultValue: CGRect? = nil
}

extension EnvironmentValues {
    var kitoTooltipBounds: CGRect? {
        get { self[KitoTooltipBoundsKey.self] }
        set { self[KitoTooltipBoundsKey.self] = newValue }
    }
}

public extension View {
    /// Shows a tip beside this view while `isPresented` is true. The tip sits on `placement` when
    /// there's room and flips to the other side (or beside) when there isn't, staying inside the
    /// screen, or inside the nearest `.kitoTooltipBounds()`.
    ///
    /// ```swift
    /// Button("Filters", systemImage: "slider.horizontal.3") { … }
    ///     .kitoTooltip(isPresented: $showTip, title: "New filters",
    ///                  message: "Sort by distance and price.", systemImage: "sparkles")
    /// ```
    ///
    /// The tip is drawn in an overlay of this view, so give the view (or its container) a higher
    /// `zIndex` if later siblings would draw over the tip.
    ///
    /// - Parameters:
    ///   - title: Optional bold first line.
    ///   - message: The tip's text.
    ///   - systemImage: Optional SF Symbol in a tinted circle.
    ///   - placement: The side to prefer. `.auto` picks below, then above, then beside.
    ///   - dismissButtonTitle: A button that closes the tip, e.g. "Got it". `nil` for none; tapping
    ///     the tip always closes it.
    ///   - autoDismiss: Closes the tip after this long. `nil` keeps it open.
    ///   - tint: Accent for the icon and button. Defaults to the theme's primary.
    func kitoTooltip(
        isPresented: Binding<Bool>,
        title: String? = nil,
        message: String,
        systemImage: String? = nil,
        placement: KitoTourPlacement = .auto,
        dismissButtonTitle: String? = nil,
        autoDismiss: Duration? = nil,
        tint: Color? = nil
    ) -> some View {
        modifier(KitoTooltipModifier(isPresented: isPresented, title: title, message: message, systemImage: systemImage,
                                     placement: placement, dismissButtonTitle: dismissButtonTitle,
                                     autoDismiss: autoDismiss, tint: tint))
    }

    /// Keeps `.kitoTooltip` tips inside this view instead of the screen, e.g. in a card or a
    /// preview frame.
    func kitoTooltipBounds() -> some View {
        modifier(KitoTooltipBoundsModifier())
    }
}

private struct KitoTooltipBoundsModifier: ViewModifier {
    @State private var frame: CGRect?

    func body(content: Content) -> some View {
        content
            .environment(\.kitoTooltipBounds, frame)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
    }
}

private struct KitoTooltipModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String?
    let message: String
    let systemImage: String?
    let placement: KitoTourPlacement
    let dismissButtonTitle: String?
    let autoDismiss: Duration?
    let tint: Color?

    @State private var anchorFrame: CGRect = .zero
    @Environment(\.kitoTooltipBounds) private var customBounds
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { anchorFrame = $0 }
            .overlay(alignment: .topLeading) { overlay }
            .animation(KitoTourMotion.pop(reduceMotion), value: isPresented)
            .task(id: isPresented) { await dismissLater() }
    }

    @ViewBuilder
    private var overlay: some View {
        if isPresented {
            KitoTooltipPanel(title: title, message: message, systemImage: systemImage, placement: placement,
                             dismissButtonTitle: dismissButtonTitle, palette: KitoTourPalette(theme: theme, tint: tint),
                             target: CGRect(origin: .zero, size: anchorFrame.size),
                             bounds: localBounds) { isPresented = false }
                .transition(KitoTourMotion.appear(reduceMotion))
        }
    }

    /// The allowed area in this view's own layout-direction coordinates (global frames are
    /// physical; the tip's `.position` mirrors in right-to-left layouts).
    private var localBounds: CGRect {
        let global = customBounds ?? KitoTooltipScreen.safeBounds()
        let local = global.offsetBy(dx: -anchorFrame.minX, dy: -anchorFrame.minY)
        return KitoTourGeometry.layoutRect(local, inWidth: anchorFrame.width, rightToLeft: layoutDirection == .rightToLeft)
            .insetBy(dx: 12, dy: 8)
    }

    private func dismissLater() async {
        guard isPresented, let autoDismiss else { return }
        try? await Task.sleep(for: autoDismiss)
        guard !Task.isCancelled else { return }
        isPresented = false
    }
}

/// The tooltip itself, positioned by `KitoTourCallout` around a frame of the anchor's size.
private struct KitoTooltipPanel: View {
    let title: String?
    let message: String
    let systemImage: String?
    let placement: KitoTourPlacement
    let dismissButtonTitle: String?
    let palette: KitoTourPalette
    let target: CGRect
    let bounds: CGRect
    let dismiss: () -> Void

    private var theme: KitoTheme { palette.theme }

    var body: some View {
        KitoTourCallout(target: target, bounds: bounds, placement: placement, width: 260, gap: 10,
                        cornerRadius: 16, palette: palette) {
            content
        }
        .frame(width: target.width, height: target.height, alignment: .topLeading)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.onAccent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(palette.accentGradient))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                if let title {
                    Text(title)
                        .font(theme.typography.bodyEmphasized)
                        .foregroundStyle(palette.text)
                }
                Text(message)
                    .font(theme.typography.label)
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let dismissButtonTitle {
                    Button(dismissButtonTitle, action: dismiss)
                        .buttonStyle(KitoTourPrimaryButtonStyle(palette: palette))
                        .padding(.top, theme.spacing.xs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityAction(named: "Dismiss", dismiss)
        .accessibilityAction(.escape, dismiss)
        .kitoTourVoiceOverFocus(message, announcing: "")
    }
}

/// The key window's safe area in screen coordinates, for tips with no `.kitoTooltipBounds()`.
@MainActor
enum KitoTooltipScreen {
    static func safeBounds() -> CGRect {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        guard let window = windows.first(where: \.isKeyWindow) ?? windows.first else {
            return CGRect(x: 0, y: 0, width: 390, height: 844)
        }
        return window.bounds.inset(by: window.safeAreaInsets)
    }
}
