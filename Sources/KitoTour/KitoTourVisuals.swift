//
//  KitoTourVisuals.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import UIKit
import KitoCore

/// Animations shared by every style. With Reduce Motion on, things fade instead of moving.
enum KitoTourMotion {
    static func move(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.48, dampingFraction: 0.82)
    }

    static func pop(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.34, dampingFraction: 0.68)
    }

    static func appear(_ reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity)
    }
}

/// Colours derived from the theme and an optional tint.
struct KitoTourPalette {
    let theme: KitoTheme
    let tint: Color?

    var accent: Color { tint ?? theme.colors.primary }
    /// Text on the accent: the theme's pair for its own primary, white on a custom tint.
    var onAccent: Color { tint == nil ? theme.colors.onPrimary : .white }
    var accentGradient: LinearGradient {
        LinearGradient(colors: [accent.opacity(0.82), accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    var surface: Color { theme.colors.surface }
    var text: Color { theme.colors.onSurface }
    var secondaryText: Color { theme.colors.onSurface.opacity(0.66) }
    var border: Color { theme.colors.border }
}

/// A rounded rectangle with an arrow on one edge, pointing out of it. The arrow slides along the
/// edge when `arrowOffset` animates.
public struct KitoTooltipBubbleShape: Shape {
    /// The edge the arrow is on, or `nil` for no arrow.
    public var arrowEdge: KitoTooltipSide?
    /// From the left (top/bottom edges) or top (side edges) of the bubble to the arrow's centre.
    public var arrowOffset: CGFloat
    public var cornerRadius: CGFloat
    public var arrowSize: CGSize

    public init(arrowEdge: KitoTooltipSide?, arrowOffset: CGFloat, cornerRadius: CGFloat = 18,
                arrowSize: CGSize = CGSize(width: 22, height: 10)) {
        self.arrowEdge = arrowEdge
        self.arrowOffset = arrowOffset
        self.cornerRadius = cornerRadius
        self.arrowSize = arrowSize
    }

    public var animatableData: CGFloat {
        get { arrowOffset }
        set { arrowOffset = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        arrow(on: .top, in: rect, radius: radius, path: &path)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: radius)
        arrow(on: .trailing, in: rect, radius: radius, path: &path)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: radius)
        arrow(on: .bottom, in: rect, radius: radius, path: &path)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: radius)
        arrow(on: .leading, in: rect, radius: radius, path: &path)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: radius)
        path.closeSubpath()
        return path
    }

    /// Adds the arrow's three points if it's on `edge`, walking the outline clockwise.
    private func arrow(on edge: KitoTooltipSide, in rect: CGRect, radius: CGFloat, path: inout Path) {
        guard arrowEdge == edge else { return }
        let points = arrowPoints(on: edge, in: rect, radius: radius)
        path.addLine(to: points.start)
        path.addLine(to: lerp(points.start, points.tip, 0.8))
        path.addQuadCurve(to: lerp(points.end, points.tip, 0.8), control: points.tip)
        path.addLine(to: points.end)
    }

    private func arrowPoints(on edge: KitoTooltipSide, in rect: CGRect, radius: CGFloat) -> (start: CGPoint, tip: CGPoint, end: CGPoint) {
        let half = arrowSize.width / 2
        let along = edge.isVertical ? rect.width : rect.height
        let centre = min(max(arrowOffset, radius + half), along - radius - half)
        let depth = arrowSize.height
        switch edge {
        case .top:
            let x = rect.minX + centre
            return (CGPoint(x: x - half, y: rect.minY), CGPoint(x: x, y: rect.minY - depth), CGPoint(x: x + half, y: rect.minY))
        case .trailing:
            let y = rect.minY + centre
            return (CGPoint(x: rect.maxX, y: y - half), CGPoint(x: rect.maxX + depth, y: y), CGPoint(x: rect.maxX, y: y + half))
        case .bottom:
            let x = rect.minX + centre
            return (CGPoint(x: x + half, y: rect.maxY), CGPoint(x: x, y: rect.maxY + depth), CGPoint(x: x - half, y: rect.maxY))
        case .leading:
            let y = rect.minY + centre
            return (CGPoint(x: rect.minX, y: y + half), CGPoint(x: rect.minX - depth, y: y), CGPoint(x: rect.minX, y: y - half))
        }
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}

/// The step's artwork: an image, or a symbol in a tinted circle.
struct KitoTourArtwork: View {
    let step: KitoTourStep
    let palette: KitoTourPalette
    var size: CGFloat = 38

    var body: some View {
        if let symbol = step.systemImage {
            Image(systemName: symbol)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(palette.onAccent)
                .frame(width: size, height: size)
                .background(Circle().fill(palette.accentGradient))
                .shadow(color: palette.accent.opacity(0.35), radius: 6, y: 3)
                .accessibilityHidden(true)
        }
    }
}

/// A wide image at the top of a tip.
struct KitoTourHeroImage: View {
    let image: Image
    let theme: KitoTheme

    var body: some View {
        image
            .resizable()
            .scaledToFill()
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Dots for each step, the current one stretched into a pill.
struct KitoTourProgressDots: View {
    let count: Int
    let index: Int
    let palette: KitoTourPalette

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { position in
                Capsule()
                    .fill(position <= index ? palette.accent : palette.border)
                    .frame(width: position == index ? 18 : 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A filled capsule button in the accent colour.
struct KitoTourPrimaryButtonStyle: ButtonStyle {
    let palette: KitoTourPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(palette.theme.typography.label.weight(.semibold))
            .foregroundStyle(palette.onAccent)
            .padding(.horizontal, 16)
            .frame(minHeight: 36)
            .background(Capsule().fill(palette.accentGradient))
            .shadow(color: palette.accent.opacity(configuration.isPressed ? 0.15 : 0.32), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A round, quiet button for Back.
struct KitoTourRoundButtonStyle: ButtonStyle {
    let palette: KitoTourPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(palette.theme.typography.label.weight(.semibold))
            .foregroundStyle(palette.text)
            .frame(width: 36, height: 36)
            .background(Circle().fill(palette.theme.colors.surfaceMuted))
            .overlay(Circle().stroke(palette.border, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Moves VoiceOver focus to this element whenever the step changes, then queues `announcement`
/// (usually the step's message) so it's read after the focused element.
struct KitoTourVoiceOverFocus: ViewModifier {
    let stepID: String
    let announcement: String

    @AccessibilityFocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityFocused($focused)
            .task(id: stepID) {
                guard UIAccessibility.isVoiceOverRunning else { return }
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                focused = true
                KitoTourAnnouncer.announce(announcement)
            }
    }
}

/// Posts VoiceOver announcements that wait for current speech instead of cutting it off.
@MainActor
enum KitoTourAnnouncer {
    static func announce(_ text: String) {
        guard !text.isEmpty else { return }
        let queued = NSAttributedString(string: text, attributes: [.accessibilitySpeechQueueAnnouncement: true])
        UIAccessibility.post(notification: .announcement, argument: queued)
    }
}

extension View {
    /// See `KitoTourVoiceOverFocus`.
    func kitoTourVoiceOverFocus(_ stepID: String, announcing announcement: String) -> some View {
        modifier(KitoTourVoiceOverFocus(stepID: stepID, announcement: announcement))
    }
}
