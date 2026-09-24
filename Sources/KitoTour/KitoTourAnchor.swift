//
//  KitoTourAnchor.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI

/// Collects the bounds of every view marked with `.kitoTourAnchor(_:)`.
struct KitoTourAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, newer in newer }
    }
}

/// Passes taps on anchored views up to the tour that's showing.
struct KitoTourTapRelay {
    var send: @MainActor (String) -> Void = { _ in }
}

private struct KitoTourTapRelayKey: EnvironmentKey {
    static let defaultValue = KitoTourTapRelay()
}

extension EnvironmentValues {
    var kitoTourTapRelay: KitoTourTapRelay {
        get { self[KitoTourTapRelayKey.self] }
        set { self[KitoTourTapRelayKey.self] = newValue }
    }
}

public extension View {
    /// Marks this view as something a tour step can point at. Use the same id as the step's
    /// `anchor`. Anchors can be anywhere inside the view that has `.kitoTour(…)`.
    ///
    /// ```swift
    /// Button("Send", systemImage: "paperplane.fill") { … }
    ///     .kitoTourAnchor("send")
    /// ```
    func kitoTourAnchor(_ id: String) -> some View {
        modifier(KitoTourAnchorModifier(id: id))
    }
}

private struct KitoTourAnchorModifier: ViewModifier {
    let id: String
    @Environment(\.kitoTourTapRelay) private var relay

    func body(content: Content) -> some View {
        content
            .anchorPreference(key: KitoTourAnchorKey.self, value: .bounds) { [id: $0] }
            .simultaneousGesture(TapGesture().onEnded { relay.send(id) })
    }
}
