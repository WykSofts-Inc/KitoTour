//
//  KitoTourStep.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI

/// Where a step's tip sits relative to the element it points at.
public enum KitoTourPlacement: String, Sendable, CaseIterable {
    /// Below if there's room, otherwise above, then beside.
    case auto
    case top
    case bottom
    case leading
    case trailing

    /// The side asked for, or `nil` for `.auto`.
    public var side: KitoTooltipSide? {
        switch self {
        case .auto: nil
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        }
    }
}

/// The shape of the hole a spotlight cuts around the highlighted element.
public enum KitoSpotlightShape: Equatable, Sendable {
    /// A rounded rectangle. The radius grows with the padding so the hole stays concentric with
    /// the element's own corners.
    case roundedRect(cornerRadius: CGFloat)
    /// A circle centred on the element, wide enough for its longer side.
    case circle
    /// A pill as tall as the element.
    case capsule

    /// A rounded rectangle with a 12pt radius.
    public static let roundedRect = KitoSpotlightShape.roundedRect(cornerRadius: 12)
}

/// One stop on a tour: which element to highlight and what to say about it.
///
/// ```swift
/// KitoTourStep("send", anchor: "send-button", title: "Send money",
///              message: "Pay anyone with just their phone number.",
///              systemImage: "paperplane.fill", spotlight: .circle)
/// ```
public struct KitoTourStep: Identifiable, Equatable {
    public var id: String
    /// The id given to `.kitoTourAnchor(_:)` on the element to highlight. A step whose anchor
    /// isn't on screen shows its tip in the middle, without a spotlight.
    public var anchor: String
    public var title: String
    public var message: String
    /// An SF Symbol shown next to the title.
    public var systemImage: String?
    /// An image shown above the text, e.g. a screenshot or illustration. Wins over `systemImage`.
    public var image: Image?
    public var placement: KitoTourPlacement
    public var spotlight: KitoSpotlightShape
    /// Extra room between the element and the edge of the spotlight.
    public var spotlightPadding: CGFloat
    /// The primary button's title. `nil` uses "Next", or "Done" on the last step.
    public var actionTitle: String?
    /// Whether tapping the highlighted element itself moves the tour on. The element still
    /// receives the tap, so a user can try the real button.
    public var advancesOnTargetTap: Bool

    public init(
        _ id: String,
        anchor: String? = nil,
        title: String,
        message: String,
        systemImage: String? = nil,
        image: Image? = nil,
        placement: KitoTourPlacement = .auto,
        spotlight: KitoSpotlightShape = .roundedRect,
        spotlightPadding: CGFloat = 8,
        actionTitle: String? = nil,
        advancesOnTargetTap: Bool = false
    ) {
        self.id = id
        self.anchor = anchor ?? id
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.image = image
        self.placement = placement
        self.spotlight = spotlight
        self.spotlightPadding = spotlightPadding
        self.actionTitle = actionTitle
        self.advancesOnTargetTap = advancesOnTargetTap
    }
}

/// A named, versioned list of steps. Bump `version` when the tour changes enough that people who
/// have seen it should see it again.
public struct KitoTour: Identifiable, Equatable {
    public var id: String
    public var version: Int
    /// Shown by the `.checklist` style, e.g. "Getting started".
    public var title: String
    public var steps: [KitoTourStep]

    public init(_ id: String, version: Int = 1, title: String = "Getting started", steps: [KitoTourStep]) {
        self.id = id
        self.version = version
        self.title = title
        self.steps = steps
    }

    /// The key the tour's "seen" flag is stored under.
    public var seenKey: String { "tour.\(id)" }
}

/// How a tour ended.
public enum KitoTourOutcome: String, Sendable {
    /// The last step was reached, or `finish()` was called.
    case completed
    /// Skip was tapped.
    case skipped
}
