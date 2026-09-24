//
//  KitoTourNavigation.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// The step-by-step state of a tour as a plain value: which step is showing, which steps are
/// done, and how it ended. `KitoTourController` wraps one; use it directly to drive your own UI.
///
/// ```swift
/// var navigation = KitoTourNavigation(stepCount: 3)
/// navigation.handle(.start)     // .active(0)
/// navigation.handle(.next)      // .active(1), step 0 completed
/// navigation.handle(.skip)      // .finished(.skipped)
/// ```
public struct KitoTourNavigation: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case active(Int)
        case finished(KitoTourOutcome)
    }

    public enum Event: Equatable, Sendable {
        /// Show the first step and forget completed steps.
        case start
        /// Complete the current step and show the next, or finish after the last.
        case next
        /// Show the previous step.
        case back
        /// End the tour early.
        case skip
        /// Complete every step and end the tour.
        case finish
        /// Show a particular step, e.g. from a checklist. Starts the tour if it isn't running.
        case jump(to: Int)
    }

    public let stepCount: Int
    public private(set) var phase: Phase = .idle
    /// Indices of the steps the user has moved past.
    public private(set) var completed: Set<Int> = []

    public init(stepCount: Int) {
        self.stepCount = max(0, stepCount)
    }

    /// Applies an event. Returns `false` when it doesn't apply (e.g. `back` on the first step) and
    /// nothing changed.
    @discardableResult
    public mutating func handle(_ event: Event) -> Bool {
        let before = self
        switch event {
        case .start: start()
        case .next: advance()
        case .back: goBack()
        case .skip: end(.skipped)
        case .finish: finishAll()
        case .jump(let index): jump(to: index)
        }
        return before != self
    }

    // MARK: Reading

    /// The index of the step showing, if the tour is running.
    public var index: Int? {
        if case .active(let index) = phase { return index }
        return nil
    }

    public var isActive: Bool { index != nil }
    public var isFirst: Bool { index == 0 }
    public var isLast: Bool { index.map { $0 == stepCount - 1 } ?? false }

    public var outcome: KitoTourOutcome? {
        if case .finished(let outcome) = phase { return outcome }
        return nil
    }

    /// How far through the tour the current step is, from `1/stepCount` on the first step to `1`
    /// on the last. `0` before it starts, `1` once it has finished.
    public var progress: Double {
        guard stepCount > 0 else { return 0 }
        switch phase {
        case .idle: return 0
        case .active(let index): return Double(index + 1) / Double(stepCount)
        case .finished: return 1
        }
    }

    public var checklist: KitoChecklistProgress {
        KitoChecklistProgress(completed: completed.count, total: stepCount)
    }

    // MARK: Transitions

    private mutating func start() {
        completed = []
        phase = stepCount > 0 ? .active(0) : .finished(.completed)
    }

    private mutating func advance() {
        guard let index else { return }
        completed.insert(index)
        let next = nextIncomplete(after: index)
        phase = next.map { .active($0) } ?? .finished(.completed)
    }

    /// The next step after `index`, skipping ones already done (from a checklist). If every later
    /// step is done, the earliest undone step; `nil` when all are done.
    private func nextIncomplete(after index: Int) -> Int? {
        let later = (index + 1)..<max(index + 1, stepCount)
        if let next = later.first(where: { !completed.contains($0) }) { return next }
        return (0..<stepCount).first { !completed.contains($0) }
    }

    private mutating func goBack() {
        guard let index, index > 0 else { return }
        phase = .active(index - 1)
    }

    private mutating func end(_ outcome: KitoTourOutcome) {
        guard isActive else { return }
        phase = .finished(outcome)
    }

    private mutating func finishAll() {
        guard isActive else { return }
        completed = Set(0..<stepCount)
        phase = .finished(.completed)
    }

    private mutating func jump(to index: Int) {
        guard (0..<stepCount).contains(index) else { return }
        phase = .active(index)
    }
}

/// "2/5" progress for a checklist.
public struct KitoChecklistProgress: Equatable, Sendable {
    public let completed: Int
    public let total: Int

    /// `completed` is clamped to `0...total`.
    public init(completed: Int, total: Int) {
        self.total = max(0, total)
        self.completed = min(max(0, completed), self.total)
    }

    public var remaining: Int { total - completed }
    public var isComplete: Bool { total > 0 && completed == total }
    /// `0...1`; `0` for an empty list.
    public var fraction: Double { total == 0 ? 0 : Double(completed) / Double(total) }
    /// "2/5".
    public var label: String { "\(completed)/\(total)" }
    /// "2 of 5 done", for VoiceOver.
    public var accessibilityLabel: String { "\(completed) of \(total) done" }

    /// The first index not in `done`, or `nil` when every item is done.
    public static func nextIndex(completed done: Set<Int>, total: Int) -> Int? {
        (0..<max(0, total)).first { !done.contains($0) }
    }
}
