//
//  KitoTooltipLayout.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import CoreGraphics

/// A side of the highlighted element. `leading` is the low-x side of the coordinate space.
/// Tours and `.kitoTooltip` hand the layout frames in layout-direction coordinates (x counted
/// from the right in right-to-left languages), so `.leading` is the side text starts from.
public enum KitoTooltipSide: String, Sendable, CaseIterable {
    case top
    case bottom
    case leading
    case trailing

    public var opposite: KitoTooltipSide {
        switch self {
        case .top: .bottom
        case .bottom: .top
        case .leading: .trailing
        case .trailing: .leading
        }
    }

    /// Above or below the element.
    public var isVertical: Bool { self == .top || self == .bottom }
}

/// Where a tip goes: the side of the element it sits on, its frame, and where along its edge the
/// arrow points.
///
/// ```swift
/// let layout = KitoTooltipLayout.solve(target: button.frame, bubble: CGSize(width: 280, height: 120),
///                                      in: safeArea, placement: .auto)
/// layout.side          // .bottom when there's room below, otherwise .top, then beside
/// layout.frame         // kept inside `safeArea`
/// layout.arrowOffset   // from the bubble's left (or top) edge to the arrow's centre
/// ```
public struct KitoTooltipLayout: Equatable, Sendable {
    /// The side of the element the bubble sits on. The arrow is on the bubble's opposite edge.
    public var side: KitoTooltipSide
    public var frame: CGRect
    /// For a bubble above or below: from its left edge to the arrow's centre. Beside: from its
    /// top edge. Kept at least `arrowInset` from either end so the arrow clears the corners.
    public var arrowOffset: CGFloat
    /// Whether the bubble fits on `side` without overlapping the element.
    public var fits: Bool

    /// The edge of the bubble the arrow is on.
    public var arrowEdge: KitoTooltipSide { side.opposite }

    /// - Parameters:
    ///   - target: The element's frame.
    ///   - bubble: The bubble's size, without its arrow.
    ///   - bounds: The area the bubble must stay inside, usually the safe area minus a margin.
    ///   - placement: The side asked for. It's used when it has room; otherwise the opposite side,
    ///     then whichever side has room.
    ///   - gap: Space between the element and the bubble, including the arrow.
    ///   - arrowInset: The closest the arrow's centre may come to the bubble's ends.
    public static func solve(
        target: CGRect,
        bubble: CGSize,
        in bounds: CGRect,
        placement: KitoTourPlacement = .auto,
        gap: CGFloat = 12,
        arrowInset: CGFloat = 22
    ) -> KitoTooltipLayout {
        let side = chooseSide(target: target, bubble: bubble, in: bounds, placement: placement, gap: gap)
        let frame = position(on: side, target: target, bubble: bubble, in: bounds, gap: gap)
        let offset = arrowOffset(on: side, target: target, frame: frame, inset: arrowInset)
        let fits = room(on: side, around: target, in: bounds) >= needed(on: side, bubble: bubble, gap: gap)
        return KitoTooltipLayout(side: side, frame: frame, arrowOffset: offset, fits: fits)
    }

    // MARK: Choosing a side

    /// Free space between the element and `bounds` on `side`.
    public static func room(on side: KitoTooltipSide, around target: CGRect, in bounds: CGRect) -> CGFloat {
        switch side {
        case .top: target.minY - bounds.minY
        case .bottom: bounds.maxY - target.maxY
        case .leading: target.minX - bounds.minX
        case .trailing: bounds.maxX - target.maxX
        }
    }

    static func needed(on side: KitoTooltipSide, bubble: CGSize, gap: CGFloat) -> CGFloat {
        (side.isVertical ? bubble.height : bubble.width) + gap
    }

    /// The sides to try, best first.
    static func candidates(for placement: KitoTourPlacement, target: CGRect, in bounds: CGRect) -> [KitoTooltipSide] {
        let below = room(on: .bottom, around: target, in: bounds)
        let above = room(on: .top, around: target, in: bounds)
        let vertical: [KitoTooltipSide] = below >= above ? [.bottom, .top] : [.top, .bottom]
        let after = room(on: .trailing, around: target, in: bounds)
        let before = room(on: .leading, around: target, in: bounds)
        let horizontal: [KitoTooltipSide] = after >= before ? [.trailing, .leading] : [.leading, .trailing]
        let automatic = vertical + horizontal
        guard let asked = placement.side else { return automatic }
        let preferred = [asked, asked.opposite]
        return preferred + automatic.filter { !preferred.contains($0) }
    }

    /// The first candidate with room, or the one closest to having room.
    public static func chooseSide(
        target: CGRect,
        bubble: CGSize,
        in bounds: CGRect,
        placement: KitoTourPlacement,
        gap: CGFloat
    ) -> KitoTooltipSide {
        let sides = candidates(for: placement, target: target, in: bounds)
        let spare = { (side: KitoTooltipSide) -> CGFloat in
            room(on: side, around: target, in: bounds) - needed(on: side, bubble: bubble, gap: gap)
        }
        if let fitting = sides.first(where: { spare($0) >= 0 }) { return fitting }
        // Nothing fits. A vertical side overlapping a little reads better than a squeezed side one.
        let vertical = sides.filter(\.isVertical)
        return vertical.max { spare($0) < spare($1) } ?? .bottom
    }

    // MARK: Positioning

    static func position(on side: KitoTooltipSide, target: CGRect, bubble: CGSize, in bounds: CGRect, gap: CGFloat) -> CGRect {
        let origin: CGPoint
        switch side {
        case .top:
            origin = CGPoint(x: target.midX - bubble.width / 2, y: target.minY - gap - bubble.height)
        case .bottom:
            origin = CGPoint(x: target.midX - bubble.width / 2, y: target.maxY + gap)
        case .leading:
            origin = CGPoint(x: target.minX - gap - bubble.width, y: target.midY - bubble.height / 2)
        case .trailing:
            origin = CGPoint(x: target.maxX + gap, y: target.midY - bubble.height / 2)
        }
        let x = clamp(origin.x, low: bounds.minX, high: bounds.maxX - bubble.width)
        let y = clamp(origin.y, low: bounds.minY, high: bounds.maxY - bubble.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: bubble)
    }

    static func arrowOffset(on side: KitoTooltipSide, target: CGRect, frame: CGRect, inset: CGFloat) -> CGFloat {
        if side.isVertical {
            return clampedOffset(target.midX - frame.minX, length: frame.width, inset: inset)
        }
        return clampedOffset(target.midY - frame.minY, length: frame.height, inset: inset)
    }

    static func clampedOffset(_ value: CGFloat, length: CGFloat, inset: CGFloat) -> CGFloat {
        guard length > inset * 2 else { return length / 2 }
        return clamp(value, low: inset, high: length - inset)
    }

    /// Clamps to `low...high`, preferring `low` when the range is empty (a bubble wider than the
    /// bounds starts at their leading edge).
    static func clamp(_ value: CGFloat, low: CGFloat, high: CGFloat) -> CGFloat {
        max(low, min(value, high))
    }
}

/// The hole a spotlight cuts: a rectangle and a corner radius, so every shape (rounded rect,
/// capsule, circle) can morph smoothly into any other.
/// Anchor and global frames are physical (x from the screen's left edge), while `.position`,
/// offsets and shapes are laid out along the layout direction (x from the right edge in
/// right-to-left languages). This moves a physical rect into layout coordinates.
enum KitoTourGeometry {
    static func layoutRect(_ rect: CGRect, inWidth width: CGFloat, rightToLeft: Bool) -> CGRect {
        guard rightToLeft else { return rect }
        return CGRect(x: width - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
    }
}

public struct KitoSpotlightCutout: Equatable, Sendable {
    public var rect: CGRect
    public var cornerRadius: CGFloat

    public init(rect: CGRect, cornerRadius: CGFloat) {
        self.rect = rect
        self.cornerRadius = max(0, min(cornerRadius, min(rect.width, rect.height) / 2))
    }

    /// The hole around `target`, grown by `padding` on every side.
    public static func around(_ target: CGRect, shape: KitoSpotlightShape, padding: CGFloat) -> KitoSpotlightCutout {
        let grown = inflate(target, by: padding)
        switch shape {
        case .roundedRect(let radius):
            return KitoSpotlightCutout(rect: grown, cornerRadius: radius + max(0, padding))
        case .capsule:
            return KitoSpotlightCutout(rect: grown, cornerRadius: min(grown.width, grown.height) / 2)
        case .circle:
            let diameter = max(grown.width, grown.height)
            let square = CGRect(x: grown.midX - diameter / 2, y: grown.midY - diameter / 2, width: diameter, height: diameter)
            return KitoSpotlightCutout(rect: square, cornerRadius: diameter / 2)
        }
    }

    /// A zero-size hole at `point`, for fading in from nothing or a step with no element.
    public static func closed(at point: CGPoint) -> KitoSpotlightCutout {
        KitoSpotlightCutout(rect: CGRect(origin: point, size: .zero), cornerRadius: 0)
    }

    /// `rect` grown by `amount` on every side. A negative amount shrinks it, but never below zero
    /// size.
    public static func inflate(_ rect: CGRect, by amount: CGFloat) -> CGRect {
        let width = max(0, rect.width + amount * 2)
        let height = max(0, rect.height + amount * 2)
        return CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
    }
}
