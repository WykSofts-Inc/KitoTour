//
//  KitoTourController.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI

/// Runs a tour: which step is showing, moving between steps, and remembering that it was seen.
///
/// ```swift
/// @State private var tour = KitoTourController(.home)
///
/// HomeScreen()
///     .kitoTour(tour, style: .spotlight)
///     .onAppear { tour.startIfNeeded() }       // once per tour version
///
/// Button("Replay tour") { tour.start() }       // any time
/// ```
@MainActor
@Observable
public final class KitoTourController {
    public private(set) var tour: KitoTour
    public private(set) var navigation: KitoTourNavigation

    /// Called with each step as it's shown.
    @ObservationIgnored public var onStepChange: ((KitoTourStep) -> Void)?
    /// Called once when the tour ends, however it ends.
    @ObservationIgnored public var onFinish: ((KitoTourOutcome) -> Void)?

    @ObservationIgnored private let store: KitoSeenStore

    /// - Parameters:
    ///   - tour: The steps to show.
    ///   - store: Where "seen" is remembered. Pass a store over your own `UserDefaults` suite to
    ///     keep tours apart from the rest of the app, or for tests.
    public init(_ tour: KitoTour, store: KitoSeenStore = .standard) {
        self.tour = tour
        self.store = store
        self.navigation = KitoTourNavigation(stepCount: tour.steps.count)
    }

    // MARK: State

    public var isActive: Bool { navigation.isActive }
    public var currentIndex: Int? { navigation.index }
    public var currentStep: KitoTourStep? { currentIndex.map { tour.steps[$0] } }
    public var stepCount: Int { tour.steps.count }
    public var isFirstStep: Bool { navigation.isFirst }
    public var isLastStep: Bool { navigation.isLast }
    /// `1/stepCount` on the first step up to `1` on the last.
    public var progress: Double { navigation.progress }
    /// How the last run ended, or `nil` if it hasn't ended.
    public var outcome: KitoTourOutcome? { navigation.outcome }
    public var checklist: KitoChecklistProgress { navigation.checklist }

    public func isCompleted(_ step: KitoTourStep) -> Bool {
        guard let index = tour.steps.firstIndex(where: { $0.id == step.id }) else { return false }
        return navigation.completed.contains(index)
    }

    /// Whether this version of the tour has been finished or skipped before.
    public var hasBeenSeen: Bool { store.hasSeen(tour) }

    /// "Step 2 of 5".
    public var stepLabel: String {
        guard let currentIndex else { return "" }
        return "Step \(currentIndex + 1) of \(stepCount)"
    }

    // MARK: Moving

    /// Starts from the first step, even if the tour was seen before.
    public func start() {
        send(.start)
    }

    /// Starts only if this version hasn't been seen. Returns whether it started.
    @discardableResult
    public func startIfNeeded() -> Bool {
        guard !hasBeenSeen, !isActive else { return false }
        start()
        return true
    }

    public func next() { send(.next) }
    public func back() { send(.back) }
    public func skip() { send(.skip) }
    /// Marks every step done and ends the tour.
    public func finish() { send(.finish) }

    /// Shows the step with `id`, starting the tour if needed.
    public func go(to id: KitoTourStep.ID) {
        guard let index = tour.steps.firstIndex(where: { $0.id == id }) else { return }
        send(.jump(to: index))
    }

    /// Forgets that this tour was seen, so `startIfNeeded()` shows it again.
    public func resetSeen() {
        store.reset(tour)
    }

    /// Replaces the steps, e.g. after loading them from a server. Stops a running tour.
    public func update(_ tour: KitoTour) {
        self.tour = tour
        navigation = KitoTourNavigation(stepCount: tour.steps.count)
    }

    /// Called when the highlighted element is tapped.
    func targetTapped(_ anchor: String) {
        guard let step = currentStep, step.anchor == anchor, step.advancesOnTargetTap else { return }
        next()
    }

    private func send(_ event: KitoTourNavigation.Event) {
        let wasActive = navigation.isActive
        let before = navigation.index
        guard navigation.handle(event) else { return }
        if let step = currentStep, navigation.index != before || !wasActive {
            onStepChange?(step)
        }
        if wasActive, let outcome = navigation.outcome {
            store.markSeen(tour)
            onFinish?(outcome)
        }
    }
}
