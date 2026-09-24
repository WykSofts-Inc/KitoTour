//
//  KitoTourStyles.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

// MARK: - Spotlight

/// Dimmed screen, a hole that morphs between elements, and a tooltip pointing at the hole.
struct KitoSpotlightTourView: View {
    let scene: KitoTourScene

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let cutout = scene.cutout
        ZStack {
            KitoSpotlightBackdrop(cutout: cutout, palette: scene.palette,
                                  passesTouches: scene.step.advancesOnTargetTap, showsRing: scene.target != nil)
                .animation(KitoTourMotion.move(reduceMotion), value: cutout)
            KitoTourCallout(target: scene.target.map { _ in cutout.rect }, bounds: scene.safe,
                            placement: scene.step.placement, palette: scene.palette) {
                KitoTourTipContent(controller: scene.controller, step: scene.step, palette: scene.palette)
            }
        }
    }
}

// MARK: - Pulse

/// A beacon on the element and a compact tip. Nothing is dimmed and the screen stays usable.
struct KitoPulseTourView: View {
    let scene: KitoTourScene

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The beacon: a circle round the element's centre, a little wider than its shorter side.
    private var beacon: CGRect? {
        guard let target = scene.target else { return nil }
        let diameter = min(max(min(target.width, target.height) + 16, 36), 72)
        return CGRect(x: target.midX - diameter / 2, y: target.midY - diameter / 2, width: diameter, height: diameter)
    }

    var body: some View {
        ZStack {
            if let beacon {
                KitoPulseBeacon(diameter: beacon.width, color: scene.palette.accent)
                    .position(x: beacon.midX, y: beacon.midY)
                    .animation(KitoTourMotion.move(reduceMotion), value: beacon)
            }
            KitoTourCallout(target: beacon, bounds: scene.safe, placement: scene.step.placement,
                            width: 270, gap: 10, cornerRadius: 18, palette: scene.palette) {
                KitoTourTipContent(controller: scene.controller, step: scene.step, palette: scene.palette, compact: true)
            }
        }
    }
}

// MARK: - Card

/// A card along the bottom, or the top when the element is low on screen, with a notch that
/// slides to point at the element. A light dim and a ring show which element it means.
struct KitoCardTourView: View {
    let scene: KitoTourScene

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: KitoTheme { scene.theme }
    private var palette: KitoTourPalette { scene.palette }

    /// The card goes to the top when the element is in the lower part of the screen.
    private var atTop: Bool {
        guard let target = scene.target else { return false }
        return target.midY > scene.size.height * 0.55
    }

    private var cardWidth: CGFloat { min(scene.safe.width, 520) }
    private var cardMinX: CGFloat { scene.safe.midX - cardWidth / 2 }

    private var arrowOffset: CGFloat {
        guard let target = scene.target else { return cardWidth / 2 }
        return KitoTooltipLayout.clampedOffset(target.midX - cardMinX, length: cardWidth, inset: 30)
    }

    var body: some View {
        let cutout = scene.cutout
        ZStack {
            KitoSpotlightBackdrop(cutout: cutout, palette: palette, dimOpacity: 0.32,
                                  passesTouches: scene.step.advancesOnTargetTap, showsRing: scene.target != nil)
                .animation(KitoTourMotion.move(reduceMotion), value: cutout)
            card
                .frame(width: cardWidth)
                .frame(width: scene.safe.width, height: scene.safe.height, alignment: atTop ? .top : .bottom)
                .position(x: scene.safe.midX, y: scene.safe.midY)
                .animation(KitoTourMotion.move(reduceMotion), value: atTop)
                .animation(KitoTourMotion.move(reduceMotion), value: arrowOffset)
        }
    }

    private var shape: KitoTooltipBubbleShape {
        KitoTooltipBubbleShape(arrowEdge: scene.target == nil ? nil : (atTop ? .bottom : .top),
                               arrowOffset: arrowOffset, cornerRadius: theme.radii.xl + 6,
                               arrowSize: CGSize(width: 26, height: 12))
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            KitoTourProgressBar(progress: scene.controller.progress, palette: palette)
            KitoTourTipContent(controller: scene.controller, step: scene.step, palette: palette)
        }
        .padding(theme.spacing.xl)
        .background {
            ZStack {
                shape.fill(palette.surface).shadow(color: .black.opacity(0.25), radius: 30, y: 14)
                shape.stroke(palette.border.opacity(0.7), lineWidth: 0.75)
            }
        }
    }
}

/// A thin bar filling with the tour's progress.
struct KitoTourProgressBar: View {
    let progress: Double
    let palette: KitoTourPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Capsule()
            .fill(palette.theme.colors.surfaceMuted)
            .frame(height: 5)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(palette.accentGradient)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .clipShape(Capsule())
            .animation(KitoTourMotion.move(reduceMotion), value: progress)
            .accessibilityHidden(true)
    }
}
