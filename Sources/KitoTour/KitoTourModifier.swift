//
//  KitoTourModifier.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// How a tour is drawn.
public enum KitoTourStyle: String, Sendable, CaseIterable {
    /// Dims the screen, cuts a hole round the element that glides and morphs from step to step,
    /// and points at it with a tooltip.
    case spotlight
    /// No dimming: a pulsing beacon on the element and a small tip beside it. The screen stays
    /// usable.
    case pulse
    /// A card along the bottom (or top) with a notch pointing at the element, and a light dim.
    case card
    /// A dark overlay with a hand-drawn arrow and handwritten label. Tap anywhere to continue.
    case coachmark
    /// A floating "Getting started 2/5" checklist that expands into every step. Tap one to be
    /// shown where it is.
    case checklist

    /// Whether the style covers the screen, so VoiceOver stays inside the tour.
    var isModal: Bool {
        switch self {
        case .spotlight, .card, .coachmark: true
        case .pulse, .checklist: false
        }
    }
}

public extension View {
    /// Shows `controller`'s tour over this view, pointing at views inside it marked with
    /// `.kitoTourAnchor(_:)`. Put it on the screen's root container.
    ///
    /// ```swift
    /// @State private var tour = KitoTourController(.wallet)
    ///
    /// WalletScreen()
    ///     .kitoTour(tour, style: .spotlight)
    ///     .onAppear { tour.startIfNeeded() }
    /// ```
    func kitoTour(_ controller: KitoTourController, style: KitoTourStyle = .spotlight, tint: Color? = nil) -> some View {
        modifier(KitoTourHostModifier(controller: controller, style: style, tint: tint))
    }

    /// Shows `tour` while `isPresented` is true, and sets it back to false when the tour ends.
    /// Finishing or skipping marks the tour's version as seen in `store`.
    ///
    /// ```swift
    /// HomeScreen()
    ///     .kitoTour(.home, isPresented: $showTour, style: .card)
    ///     .onAppear { showTour = !KitoSeenStore.standard.hasSeen(KitoTour.home) }
    /// ```
    func kitoTour(
        _ tour: KitoTour,
        isPresented: Binding<Bool>,
        style: KitoTourStyle = .spotlight,
        tint: Color? = nil,
        store: KitoSeenStore = .standard,
        onStepChange: ((KitoTourStep) -> Void)? = nil,
        onFinish: ((KitoTourOutcome) -> Void)? = nil
    ) -> some View {
        modifier(KitoTourPresentedModifier(tour: tour, isPresented: isPresented, style: style, tint: tint, store: store,
                                           onStepChange: onStepChange, onFinish: onFinish))
    }
}

/// Reads the anchors below it and draws the tour's current step over them.
struct KitoTourHostModifier: ViewModifier {
    let controller: KitoTourController
    let style: KitoTourStyle
    let tint: Color?

    @State private var celebrating = false
    @Environment(\.kitoTheme) private var theme

    func body(content: Content) -> some View {
        content
            .environment(\.kitoTourTapRelay, KitoTourTapRelay { [controller] anchor in controller.targetTapped(anchor) })
            .overlayPreferenceValue(KitoTourAnchorKey.self) { anchors in
                overlay(anchors)
            }
            .onChange(of: controller.isActive) { wasActive, isActive in
                celebrateIfNeeded(wasActive: wasActive, isActive: isActive)
            }
    }

    private func overlay(_ anchors: [String: Anchor<CGRect>]) -> some View {
        ZStack {
            if controller.isActive || celebrating {
                KitoTourStage(controller: controller, style: style, palette: KitoTourPalette(theme: theme, tint: tint),
                              anchors: anchors, celebrating: celebrating)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: controller.isActive)
        .animation(.easeInOut(duration: 0.28), value: celebrating)
    }

    /// The checklist style ends with a moment of "All done".
    private func celebrateIfNeeded(wasActive: Bool, isActive: Bool) {
        guard style == .checklist, wasActive, !isActive, controller.outcome == .completed else { return }
        celebrating = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            celebrating = false
        }
    }
}

/// Owns a controller for the `isPresented` form of `.kitoTour`.
struct KitoTourPresentedModifier: ViewModifier {
    let tour: KitoTour
    @Binding var isPresented: Bool
    let style: KitoTourStyle
    let tint: Color?
    let onStepChange: ((KitoTourStep) -> Void)?
    let onFinish: ((KitoTourOutcome) -> Void)?

    @State private var controller: KitoTourController

    init(tour: KitoTour, isPresented: Binding<Bool>, style: KitoTourStyle, tint: Color?, store: KitoSeenStore,
         onStepChange: ((KitoTourStep) -> Void)?, onFinish: ((KitoTourOutcome) -> Void)?) {
        self.tour = tour
        _isPresented = isPresented
        self.style = style
        self.tint = tint
        self.onStepChange = onStepChange
        self.onFinish = onFinish
        _controller = State(initialValue: KitoTourController(tour, store: store))
    }

    func body(content: Content) -> some View {
        content
            .kitoTour(controller, style: style, tint: tint)
            .onAppear(perform: appeared)
            .onChange(of: isPresented) { _, shown in presentationChanged(shown) }
            .onChange(of: controller.isActive) { _, active in if !active { isPresented = false } }
            .onChange(of: tour) { _, updated in controller.update(updated) }
    }

    private func appeared() {
        controller.onStepChange = onStepChange
        controller.onFinish = onFinish
        if isPresented { controller.start() }
    }

    private func presentationChanged(_ shown: Bool) {
        if shown {
            if !controller.isActive { controller.start() }
        } else if controller.isActive {
            controller.skip()
        }
    }
}

/// Everything a style needs to draw one step.
struct KitoTourScene {
    let controller: KitoTourController
    let step: KitoTourStep
    /// The element's frame, or `nil` when it isn't on screen.
    let target: CGRect?
    let size: CGSize
    /// The safe area with a margin; tips stay inside it.
    let safe: CGRect
    let palette: KitoTourPalette

    var cutout: KitoSpotlightCutout {
        guard let target else { return .closed(at: CGPoint(x: size.width / 2, y: size.height / 2)) }
        return .around(target, shape: step.spotlight, padding: step.spotlightPadding)
    }

    var theme: KitoTheme { palette.theme }
}

/// Resolves anchors to frames in a layer that covers the whole screen, and picks the style.
struct KitoTourStage: View {
    let controller: KitoTourController
    let style: KitoTourStyle
    let palette: KitoTourPalette
    let anchors: [String: Anchor<CGRect>]
    let celebrating: Bool

    var body: some View {
        GeometryReader { outer in
            let safeGlobal = Self.safeFrame(outer)
            GeometryReader { proxy in
                layer(proxy, safe: Self.local(safeGlobal, in: proxy))
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func layer(_ proxy: GeometryProxy, safe: CGRect) -> some View {
        if style == .checklist {
            let step = controller.currentStep
            let target = step.flatMap { anchors[$0.anchor] }.map { proxy[$0] }
            KitoChecklistTourView(controller: controller, step: step, target: target, size: proxy.size, safe: safe,
                                  palette: palette, celebrating: celebrating)
        } else if let step = controller.currentStep {
            let target = anchors[step.anchor].map { proxy[$0] }
            let scene = KitoTourScene(controller: controller, step: step, target: target, size: proxy.size,
                                      safe: safe, palette: palette)
            styled(scene)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(style.isModal ? .isModal : [])
                .accessibilityAction(.escape) { controller.skip() }
        }
    }

    @ViewBuilder
    private func styled(_ scene: KitoTourScene) -> some View {
        switch style {
        case .spotlight: KitoSpotlightTourView(scene: scene)
        case .pulse: KitoPulseTourView(scene: scene)
        case .card: KitoCardTourView(scene: scene)
        case .coachmark: KitoCoachmarkTourView(scene: scene)
        case .checklist: EmptyView()
        }
    }

    /// The outer reader's safe region, in global coordinates.
    private static func safeFrame(_ proxy: GeometryProxy) -> CGRect {
        let frame = proxy.frame(in: .global)
        let insets = proxy.safeAreaInsets
        return CGRect(x: frame.minX + insets.leading, y: frame.minY + insets.top,
                      width: max(0, frame.width - insets.leading - insets.trailing),
                      height: max(0, frame.height - insets.top - insets.bottom))
    }

    /// `global` moved into `proxy`'s coordinates, with a margin so tips never touch the edges.
    private static func local(_ global: CGRect, in proxy: GeometryProxy) -> CGRect {
        let origin = proxy.frame(in: .global).origin
        let moved = global.offsetBy(dx: -origin.x, dy: -origin.y)
        return moved.insetBy(dx: 12, dy: 8)
    }
}
