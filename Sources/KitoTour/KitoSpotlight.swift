//
//  KitoSpotlight.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A spotlight hole as a shape. With `includesSurround`, the shape is everything *except* the
/// hole (fill it with `eoFill`); without, it's just the hole's outline. The hole's frame and
/// corner radius animate, so it glides and morphs from one element to the next.
struct KitoSpotlightShapeView: Shape {
    var cutout: KitoSpotlightCutout
    var includesSurround = true
    /// Grows the hole on every side without animating, for the pulse ring.
    var grow: CGFloat = 0

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>> {
        get {
            let origin = AnimatablePair(cutout.rect.minX, cutout.rect.minY)
            let size = AnimatablePair(cutout.rect.width, cutout.rect.height)
            return AnimatablePair(origin, AnimatablePair(size, cutout.cornerRadius))
        }
        set {
            let rect = CGRect(x: newValue.first.first, y: newValue.first.second,
                              width: max(0, newValue.second.first.first), height: max(0, newValue.second.first.second))
            cutout = KitoSpotlightCutout(rect: rect, cornerRadius: newValue.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if includesSurround {
            path.addRect(rect.insetBy(dx: -400, dy: -400))
        }
        let hole = KitoSpotlightCutout.inflate(cutout.rect.standardized, by: grow)
        let radius = min(cutout.cornerRadius + grow, min(hole.width, hole.height) / 2)
        if cutout.rect.width > 0.5 || cutout.rect.height > 0.5 {
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius), style: .circular)
        }
        return path
    }
}

/// The dimmed backdrop with a hole, a glowing ring round the hole and, unless Reduce Motion is on,
/// a soft ring pulsing outwards.
struct KitoSpotlightBackdrop: View {
    let cutout: KitoSpotlightCutout
    let palette: KitoTourPalette
    var dimOpacity: Double = 0.62
    /// Lets touches through the hole to the real element.
    var passesTouches = false
    var showsRing = true
    var onTapOutside: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            dim
            if showsRing { ring }
        }
    }

    private var dim: some View {
        KitoSpotlightShapeView(cutout: cutout)
            .fill(Color.black.opacity(dimOpacity), style: FillStyle(eoFill: true))
            .contentShape(KitoSpotlightShapeView(cutout: hitCutout), eoFill: true)
            .onTapGesture { onTapOutside?() }
            .accessibilityHidden(true)
    }

    /// Without a hole, the backdrop swallows every touch.
    private var hitCutout: KitoSpotlightCutout {
        passesTouches ? cutout : .closed(at: .zero)
    }

    private var ring: some View {
        ZStack {
            KitoSpotlightShapeView(cutout: cutout, includesSurround: false)
                .stroke(palette.accent, lineWidth: 2)
                .shadow(color: palette.accent.opacity(0.8), radius: 8)
            if !reduceMotion {
                KitoSpotlightPulse(cutout: cutout, color: palette.accent)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A ring that grows out of the hole and fades, every 1.8 seconds.
private struct KitoSpotlightPulse: View {
    let cutout: KitoSpotlightCutout
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let phase = Self.phase(at: context.date)
            KitoSpotlightShapeView(cutout: cutout, includesSurround: false, grow: CGFloat(phase) * 14)
                .stroke(color.opacity(0.7 * (1 - phase)), lineWidth: 2)
        }
    }

    static func phase(at date: Date) -> Double {
        let period = 1.8
        return date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
    }
}

/// Concentric rings spreading from a point, like a sonar ping. Static with Reduce Motion.
struct KitoPulseBeacon: View {
    let diameter: CGFloat
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.16))
            Circle().stroke(color.opacity(0.9), lineWidth: 2)
            if reduceMotion {
                Circle().stroke(color.opacity(0.35), lineWidth: 2).scaleEffect(1.3)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let phase = KitoSpotlightPulse.phase(at: context.date)
                    ZStack {
                        ring(phase)
                        ring((phase + 0.5).truncatingRemainder(dividingBy: 1))
                    }
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func ring(_ phase: Double) -> some View {
        Circle()
            .stroke(color.opacity(0.75 * (1 - phase)), lineWidth: 2.5)
            .scaleEffect(1 + phase * 0.9)
    }
}
