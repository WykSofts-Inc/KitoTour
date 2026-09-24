//
//  KitoCoachmark.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A curved, hand-drawn arrow from `start` to `end`, bowing to one side, with an open head.
/// Trim it to draw it on.
public struct KitoCoachmarkArrowShape: Shape {
    public var start: CGPoint
    public var end: CGPoint
    /// How far the curve bows, as a fraction of its length. Negative bows the other way.
    public var bend: CGFloat
    public var headLength: CGFloat

    public init(from start: CGPoint, to end: CGPoint, bend: CGFloat = 0.28, headLength: CGFloat = 14) {
        self.start = start
        self.end = end
        self.bend = bend
        self.headLength = headLength
    }

    /// The curve's control point: the midpoint pushed sideways by `bend` × length.
    public var control: CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        return CGPoint(x: mid.x - dy * bend, y: mid.y + dx * bend)
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let control = control
        path.move(to: start)
        // A slight wobble halfway makes the line look drawn by hand.
        let wobble = CGPoint(x: control.x + (end.y - start.y) * 0.03, y: control.y - (end.x - start.x) * 0.03)
        path.addQuadCurve(to: end, control: wobble)
        let angle = atan2(end.y - control.y, end.x - control.x)
        path.move(to: head(angle + .pi - 0.5))
        path.addLine(to: end)
        path.addLine(to: head(angle + .pi + 0.45))
        return path
    }

    private func head(_ angle: CGFloat) -> CGPoint {
        CGPoint(x: end.x + cos(angle) * headLength, y: end.y + sin(angle) * headLength)
    }
}

/// A dark overlay, a chalk outline round the element, a handwritten label and an arrow drawn
/// from the label to the element. Tap anywhere to continue.
struct KitoCoachmarkTourView: View {
    let scene: KitoTourScene

    @State private var labelSize: CGSize = .zero
    @State private var drawn: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var palette: KitoTourPalette { scene.palette }
    private var theme: KitoTheme { scene.theme }
    private var labelWidth: CGFloat { min(270, scene.safe.width) }

    private var layout: KitoTooltipLayout? {
        guard scene.target != nil else { return nil }
        let chalk = KitoSpotlightCutout.inflate(scene.cutout.rect, by: 4)
        return KitoTooltipLayout.solve(target: chalk, bubble: labelSize, in: scene.safe,
                                       placement: scene.step.placement, gap: 64, arrowInset: 30)
    }

    private var labelCentre: CGPoint {
        guard let layout else { return CGPoint(x: scene.safe.midX, y: scene.safe.midY) }
        return CGPoint(x: layout.frame.midX, y: layout.frame.midY)
    }

    var body: some View {
        let cutout = scene.cutout
        ZStack {
            KitoSpotlightBackdrop(cutout: cutout, palette: palette, dimOpacity: 0.76,
                                  passesTouches: scene.step.advancesOnTargetTap, showsRing: false,
                                  onTapOutside: { scene.controller.next() })
            if scene.target != nil { chalkOutline(cutout) }
            if let arrow { arrowView(arrow) }
            label
                .frame(width: labelWidth)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { labelSize = $0 }
                .opacity(labelSize == .zero ? 0 : 1)
                .position(labelCentre)
            chrome
        }
        .animation(KitoTourMotion.move(reduceMotion), value: cutout)
        .animation(KitoTourMotion.move(reduceMotion), value: labelCentre)
        .onChange(of: scene.step.id, initial: true) { _, _ in drawArrow() }
    }

    // MARK: Pieces

    private func chalkOutline(_ cutout: KitoSpotlightCutout) -> some View {
        KitoSpotlightShapeView(cutout: cutout, includesSurround: false, grow: 4)
            .stroke(Color.white.opacity(0.92), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [7, 6]))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var arrow: KitoCoachmarkArrowShape? {
        guard let layout, scene.target != nil else { return nil }
        let chalk = KitoSpotlightCutout.inflate(scene.cutout.rect, by: 10)
        let start = Self.edgePoint(of: layout.frame, facing: layout.arrowEdge, offset: layout.arrowOffset, outset: 8)
        let end = Self.nearestPoint(on: chalk, facing: layout.side, towards: start)
        let bend: CGFloat = (scene.controller.currentIndex ?? 0).isMultiple(of: 2) ? 0.3 : -0.3
        return KitoCoachmarkArrowShape(from: start, to: end, bend: bend)
    }

    private func arrowView(_ arrow: KitoCoachmarkArrowShape) -> some View {
        arrow
            .trim(from: 0, to: drawn)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text(scene.step.title)
                .font(.custom("Noteworthy-Bold", size: 25, relativeTo: .title2))
                .foregroundStyle(.white)
                .accessibilityLabel("\(scene.controller.stepLabel). \(scene.step.title)")
                .accessibilityAddTraits(.isHeader)
                .kitoTourVoiceOverFocus(scene.step.id, announcing: scene.step.message)
            Text(scene.step.message)
                .font(.custom("Noteworthy-Light", size: 18, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.88))
            Button(scene.step.actionTitle ?? (scene.controller.isLastStep ? "Got it" : "Next")) {
                scene.controller.next()
            }
            .font(theme.typography.label.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 34)
            .overlay(Capsule().stroke(.white.opacity(0.9), lineWidth: 1.5))
            .contentShape(Capsule())
            .buttonStyle(.plain)
            .padding(.top, theme.spacing.xs)
        }
        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
    }

    /// The step count and Skip along the top, and a hint along the bottom.
    private var chrome: some View {
        VStack {
            HStack {
                Text(counter)
                    .font(theme.typography.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    .accessibilityHidden(true)
                Spacer()
                Button("Skip") { scene.controller.skip() }
                    .font(theme.typography.label.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 32)
                    .background(Capsule().fill(.white.opacity(0.16)))
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skip tour")
            }
            Spacer()
            Text("Tap anywhere to continue")
                .font(theme.typography.caption)
                .foregroundStyle(.white.opacity(0.6))
                .accessibilityHidden(true)
        }
        .frame(width: scene.safe.width, height: scene.safe.height)
        .position(x: scene.safe.midX, y: scene.safe.midY)
    }

    private var counter: String {
        "\((scene.controller.currentIndex ?? 0) + 1) / \(scene.controller.stepCount)"
    }

    private func drawArrow() {
        guard !reduceMotion else { drawn = 1; return }
        drawn = 0
        withAnimation(.easeOut(duration: 0.55).delay(0.25)) { drawn = 1 }
    }

    // MARK: Geometry

    /// A point on `edge` of `frame`, `offset` along it, pushed `outset` outwards.
    static func edgePoint(of frame: CGRect, facing edge: KitoTooltipSide, offset: CGFloat, outset: CGFloat) -> CGPoint {
        switch edge {
        case .top: CGPoint(x: frame.minX + offset, y: frame.minY - outset)
        case .bottom: CGPoint(x: frame.minX + offset, y: frame.maxY + outset)
        case .leading: CGPoint(x: frame.minX - outset, y: frame.minY + offset)
        case .trailing: CGPoint(x: frame.maxX + outset, y: frame.minY + offset)
        }
    }

    /// Where the arrow lands: on the side of `rect` facing the label, lined up with the label
    /// where possible so the arrow doesn't cross the element.
    static func nearestPoint(on rect: CGRect, facing side: KitoTooltipSide, towards point: CGPoint) -> CGPoint {
        let x = min(max(point.x, rect.minX + rect.width * 0.25), rect.maxX - rect.width * 0.25)
        let y = min(max(point.y, rect.minY + rect.height * 0.25), rect.maxY - rect.height * 0.25)
        switch side {
        case .top: return CGPoint(x: x, y: rect.minY)
        case .bottom: return CGPoint(x: x, y: rect.maxY)
        case .leading: return CGPoint(x: rect.minX, y: y)
        case .trailing: return CGPoint(x: rect.maxX, y: y)
        }
    }
}
