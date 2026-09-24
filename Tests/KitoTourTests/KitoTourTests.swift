//
//  KitoTourTests.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoTour

// MARK: - Tooltip placement

final class KitoTooltipLayoutTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 390, height: 800)
    private let bubble = CGSize(width: 280, height: 120)

    func testPrefersBelowWhenThereIsRoom() {
        let target = CGRect(x: 40, y: 100, width: 60, height: 44)
        let layout = KitoTooltipLayout.solve(target: target, bubble: bubble, in: screen, gap: 12)
        XCTAssertEqual(layout.side, .bottom)
        XCTAssertEqual(layout.arrowEdge, .top)
        XCTAssertEqual(layout.frame.minY, 156)
        XCTAssertTrue(layout.fits)
    }

    func testFlipsAboveNearTheBottom() {
        let target = CGRect(x: 150, y: 720, width: 90, height: 44)
        let layout = KitoTooltipLayout.solve(target: target, bubble: bubble, in: screen, gap: 12)
        XCTAssertEqual(layout.side, .top)
        XCTAssertEqual(layout.frame.maxY, 708)
    }

    func testAskedForSideIsKeptWhenItFits() {
        let target = CGRect(x: 150, y: 400, width: 90, height: 44)
        let layout = KitoTooltipLayout.solve(target: target, bubble: bubble, in: screen, placement: .top, gap: 12)
        XCTAssertEqual(layout.side, .top)
    }

    func testAskedForSideFlipsToItsOppositeWithoutRoom() {
        let target = CGRect(x: 150, y: 60, width: 90, height: 44)
        let layout = KitoTooltipLayout.solve(target: target, bubble: bubble, in: screen, placement: .top, gap: 12)
        XCTAssertEqual(layout.side, .bottom)
    }

    func testFallsBackToTheSideWhenNeitherAboveNorBelowFits() {
        let short = CGRect(x: 0, y: 0, width: 800, height: 300)
        let target = CGRect(x: 60, y: 100, width: 80, height: 100)
        let small = CGSize(width: 200, height: 150)
        let layout = KitoTooltipLayout.solve(target: target, bubble: small, in: short, gap: 12)
        XCTAssertEqual(layout.side, .trailing)
        XCTAssertEqual(layout.frame.minX, 152)
        XCTAssertEqual(layout.arrowEdge, .leading)
    }

    func testWhenNothingFitsPicksTheRoomierVerticalSide() {
        let tiny = CGRect(x: 0, y: 0, width: 300, height: 200)
        let target = CGRect(x: 0, y: 40, width: 300, height: 60)
        let layout = KitoTooltipLayout.solve(target: target, bubble: bubble, in: tiny, gap: 12)
        XCTAssertEqual(layout.side, .bottom)
        XCTAssertFalse(layout.fits)
        XCTAssertLessThanOrEqual(layout.frame.maxY, tiny.maxY + 0.001)
    }

    func testClampsInsideTheSafeAreaAndMovesTheArrow() {
        let safe = CGRect(x: 16, y: 59, width: 358, height: 700)
        let target = CGRect(x: 330, y: 70, width: 44, height: 44)   // top-right toolbar button
        let layout = KitoTooltipLayout.solve(target: target, bubble: bubble, in: safe, gap: 12, arrowInset: 22)
        XCTAssertEqual(layout.side, .bottom)
        XCTAssertEqual(layout.frame.maxX, safe.maxX)
        XCTAssertEqual(layout.frame.minX, 94)
        // The arrow still points at the button's centre (352), 258 from the bubble's left edge.
        XCTAssertEqual(layout.arrowOffset, 258)
    }

    func testArrowOffsetKeepsClearOfTheCorners() {
        let safe = CGRect(x: 16, y: 59, width: 358, height: 700)
        let target = CGRect(x: 0, y: 100, width: 10, height: 10)
        let layout = KitoTooltipLayout.solve(target: target, bubble: bubble, in: safe, gap: 12, arrowInset: 22)
        XCTAssertEqual(layout.frame.minX, 16)
        XCTAssertEqual(layout.arrowOffset, 22)
    }

    func testBubbleWiderThanTheBoundsStartsAtTheLeadingEdge() {
        let narrow = CGRect(x: 10, y: 0, width: 200, height: 800)
        let layout = KitoTooltipLayout.solve(target: CGRect(x: 100, y: 100, width: 20, height: 20),
                                             bubble: CGSize(width: 260, height: 80), in: narrow)
        XCTAssertEqual(layout.frame.minX, 10)
    }

    func testRoomOnEachSide() {
        let target = CGRect(x: 100, y: 200, width: 50, height: 40)
        XCTAssertEqual(KitoTooltipLayout.room(on: .top, around: target, in: screen), 200)
        XCTAssertEqual(KitoTooltipLayout.room(on: .bottom, around: target, in: screen), 560)
        XCTAssertEqual(KitoTooltipLayout.room(on: .leading, around: target, in: screen), 100)
        XCTAssertEqual(KitoTooltipLayout.room(on: .trailing, around: target, in: screen), 240)
    }

    func testTinyBubbleCentresTheArrow() {
        XCTAssertEqual(KitoTooltipLayout.clampedOffset(3, length: 30, inset: 22), 15)
    }
}

// MARK: - Spotlight geometry

final class KitoSpotlightCutoutTests: XCTestCase {
    private let button = CGRect(x: 100, y: 100, width: 80, height: 40)

    func testRoundedRectGrowsByThePaddingAndStaysConcentric() {
        let cutout = KitoSpotlightCutout.around(button, shape: .roundedRect(cornerRadius: 10), padding: 8)
        XCTAssertEqual(cutout.rect, CGRect(x: 92, y: 92, width: 96, height: 56))
        XCTAssertEqual(cutout.cornerRadius, 18)
    }

    func testCornerRadiusIsCappedAtHalfTheShortSide() {
        let cutout = KitoSpotlightCutout.around(button, shape: .roundedRect(cornerRadius: 40), padding: 4)
        XCTAssertEqual(cutout.cornerRadius, 24)
    }

    func testCapsuleIsFullyRound() {
        let cutout = KitoSpotlightCutout.around(button, shape: .capsule, padding: 6)
        XCTAssertEqual(cutout.rect.height, 52)
        XCTAssertEqual(cutout.cornerRadius, 26)
    }

    func testCircleIsASquareOnTheCentre() {
        let cutout = KitoSpotlightCutout.around(button, shape: .circle, padding: 10)
        XCTAssertEqual(cutout.rect.width, 100)
        XCTAssertEqual(cutout.rect.height, 100)
        XCTAssertEqual(cutout.rect.midX, button.midX)
        XCTAssertEqual(cutout.rect.midY, button.midY)
        XCTAssertEqual(cutout.cornerRadius, 50)
    }

    func testNegativePaddingNeverGoesBelowZero() {
        let grown = KitoSpotlightCutout.inflate(CGRect(x: 0, y: 0, width: 10, height: 10), by: -20)
        XCTAssertEqual(grown.size, .zero)
        XCTAssertEqual(grown.midX, 5)
    }

    func testClosedCutoutIsEmpty() {
        let closed = KitoSpotlightCutout.closed(at: CGPoint(x: 50, y: 60))
        XCTAssertEqual(closed.rect, CGRect(x: 50, y: 60, width: 0, height: 0))
        XCTAssertEqual(closed.cornerRadius, 0)
    }
}

// MARK: - Step navigation

final class KitoTourNavigationTests: XCTestCase {
    func testStartsAtTheFirstStep() {
        var navigation = KitoTourNavigation(stepCount: 3)
        XCTAssertEqual(navigation.phase, .idle)
        XCTAssertTrue(navigation.handle(.start))
        XCTAssertEqual(navigation.index, 0)
        XCTAssertTrue(navigation.isFirst)
        XCTAssertEqual(navigation.progress, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testNextCompletesAndFinishesAfterTheLast() {
        var navigation = KitoTourNavigation(stepCount: 2)
        navigation.handle(.start)
        navigation.handle(.next)
        XCTAssertEqual(navigation.index, 1)
        XCTAssertTrue(navigation.isLast)
        XCTAssertEqual(navigation.completed, [0])
        navigation.handle(.next)
        XCTAssertEqual(navigation.phase, .finished(.completed))
        XCTAssertEqual(navigation.completed, [0, 1])
        XCTAssertEqual(navigation.progress, 1)
    }

    func testBackStopsAtTheFirstStep() {
        var navigation = KitoTourNavigation(stepCount: 3)
        navigation.handle(.start)
        XCTAssertFalse(navigation.handle(.back))
        navigation.handle(.next)
        XCTAssertTrue(navigation.handle(.back))
        XCTAssertEqual(navigation.index, 0)
    }

    func testSkipEndsEarlyAndKeepsProgress() {
        var navigation = KitoTourNavigation(stepCount: 4)
        navigation.handle(.start)
        navigation.handle(.next)
        navigation.handle(.skip)
        XCTAssertEqual(navigation.outcome, .skipped)
        XCTAssertEqual(navigation.completed, [0])
        XCTAssertFalse(navigation.isActive)
    }

    func testFinishCompletesEverything() {
        var navigation = KitoTourNavigation(stepCount: 3)
        navigation.handle(.start)
        navigation.handle(.finish)
        XCTAssertEqual(navigation.outcome, .completed)
        XCTAssertEqual(navigation.checklist.label, "3/3")
    }

    func testEventsBeforeStartDoNothing() {
        var navigation = KitoTourNavigation(stepCount: 3)
        XCTAssertFalse(navigation.handle(.next))
        XCTAssertFalse(navigation.handle(.skip))
        XCTAssertFalse(navigation.handle(.finish))
        XCTAssertEqual(navigation.phase, .idle)
    }

    func testJumpSkipsDoneStepsWhenAdvancing() {
        var navigation = KitoTourNavigation(stepCount: 4)
        navigation.handle(.jump(to: 2))
        XCTAssertEqual(navigation.index, 2)
        navigation.handle(.next)                // 2 done
        XCTAssertEqual(navigation.index, 3)
        navigation.handle(.next)                // 3 done, wraps to the first undone
        XCTAssertEqual(navigation.index, 0)
        navigation.handle(.next)                // 0 done
        XCTAssertEqual(navigation.index, 1)
        navigation.handle(.next)
        XCTAssertEqual(navigation.outcome, .completed)
    }

    func testJumpOutOfRangeIsIgnored() {
        var navigation = KitoTourNavigation(stepCount: 2)
        XCTAssertFalse(navigation.handle(.jump(to: 5)))
        XCTAssertFalse(navigation.handle(.jump(to: -1)))
    }

    func testRestartClearsCompletedSteps() {
        var navigation = KitoTourNavigation(stepCount: 2)
        navigation.handle(.start)
        navigation.handle(.next)
        navigation.handle(.skip)
        navigation.handle(.start)
        XCTAssertEqual(navigation.index, 0)
        XCTAssertTrue(navigation.completed.isEmpty)
    }

    func testEmptyTourFinishesAtOnce() {
        var navigation = KitoTourNavigation(stepCount: 0)
        navigation.handle(.start)
        XCTAssertEqual(navigation.outcome, .completed)
        XCTAssertEqual(navigation.progress, 0)
    }
}

// MARK: - Checklist progress

final class KitoChecklistProgressTests: XCTestCase {
    func testLabelAndFraction() {
        let progress = KitoChecklistProgress(completed: 2, total: 5)
        XCTAssertEqual(progress.label, "2/5")
        XCTAssertEqual(progress.fraction, 0.4, accuracy: 0.0001)
        XCTAssertEqual(progress.remaining, 3)
        XCTAssertFalse(progress.isComplete)
        XCTAssertEqual(progress.accessibilityLabel, "2 of 5 done")
    }

    func testClampsOutOfRangeCounts() {
        XCTAssertEqual(KitoChecklistProgress(completed: 9, total: 3).completed, 3)
        XCTAssertEqual(KitoChecklistProgress(completed: -2, total: 3).completed, 0)
        XCTAssertTrue(KitoChecklistProgress(completed: 3, total: 3).isComplete)
    }

    func testEmptyListIsNeverComplete() {
        let empty = KitoChecklistProgress(completed: 0, total: 0)
        XCTAssertFalse(empty.isComplete)
        XCTAssertEqual(empty.fraction, 0)
    }

    func testNextIndexIsTheFirstUndone() {
        XCTAssertEqual(KitoChecklistProgress.nextIndex(completed: [0, 1, 3], total: 5), 2)
        XCTAssertNil(KitoChecklistProgress.nextIndex(completed: [0, 1], total: 2))
    }
}

// MARK: - Seen rules and storage

final class KitoSeenTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: KitoSeenStore!
    private let suite = "KitoTourTests.seen"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        store = KitoSeenStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testNumberedVersions() {
        XCTAssertTrue(KitoSeenRules.shouldShow(version: 1, lastSeen: nil))
        XCTAssertFalse(KitoSeenRules.shouldShow(version: 1, lastSeen: 1))
        XCTAssertTrue(KitoSeenRules.shouldShow(version: 2, lastSeen: 1))
        XCTAssertFalse(KitoSeenRules.shouldShow(version: 1, lastSeen: 3))
    }

    func testDottedVersionsCompareNumerically() {
        XCTAssertEqual(KitoSeenRules.compare("2.10", "2.9"), .orderedDescending)
        XCTAssertEqual(KitoSeenRules.compare("2.0", "2"), .orderedSame)
        XCTAssertEqual(KitoSeenRules.compare("1.4.1", "1.5"), .orderedAscending)
        XCTAssertEqual(KitoSeenRules.compare("3.0-beta", "3"), .orderedSame)
        XCTAssertTrue(KitoSeenRules.shouldShow(version: "2.4", lastSeen: nil))
        XCTAssertTrue(KitoSeenRules.shouldShow(version: "2.10", lastSeen: "2.9"))
        XCTAssertFalse(KitoSeenRules.shouldShow(version: "2.4", lastSeen: "2.4.0"))
    }

    func testStoreRemembersAndResets() {
        XCTAssertFalse(store.hasSeen("tour.home", version: 1))
        store.markSeen("tour.home", version: 1)
        XCTAssertTrue(store.hasSeen("tour.home", version: 1))
        XCTAssertFalse(store.hasSeen("tour.home", version: 2), "a new version shows again")
        store.reset("tour.home")
        XCTAssertNil(store.lastSeenVersion("tour.home"))
    }

    func testMarkingNeverLowersTheVersion() {
        store.markSeen("badge.insights", version: 3)
        store.markSeen("badge.insights", version: 1)
        XCTAssertEqual(store.lastSeenVersion("badge.insights"), 3)
    }

    func testReleasesNeverGoBackwards() {
        store.markSeen("whatsnew.app", release: "2.10")
        store.markSeen("whatsnew.app", release: "2.9")
        XCTAssertEqual(store.lastSeenRelease("whatsnew.app"), "2.10")
        XCTAssertTrue(store.hasSeen("whatsnew.app", release: "2.4"))
        XCTAssertFalse(store.hasSeen("whatsnew.app", release: "3.0"))
    }

    func testKeysUseThePrefix() {
        XCTAssertEqual(store.storageKey("tour.home"), "kito.seen.tour.home")
        store.markSeen("tour.home")
        XCTAssertEqual(defaults.integer(forKey: "kito.seen.tour.home"), 1)
    }

    func testWhatsNewShowsOncePerRelease() {
        let release = KitoWhatsNew(version: "1.2", features: [])
        XCTAssertTrue(release.shouldShow(store: store))
        release.markSeen(store: store)
        XCTAssertFalse(release.shouldShow(store: store))
        XCTAssertTrue(KitoWhatsNew(version: "1.3", features: []).shouldShow(store: store))
    }

    func testBadgesAreNewUntilSeen() {
        XCTAssertTrue(KitoFeatureBadge.isNew("insights", store: store))
        KitoFeatureBadge.markSeen("insights", store: store)
        XCTAssertFalse(KitoFeatureBadge.isNew("insights", store: store))
        XCTAssertTrue(KitoFeatureBadge.isNew("insights", version: 2, store: store))
    }
}

// MARK: - Controller

@MainActor
final class KitoTourControllerTests: XCTestCase {
    private let suite = "KitoTourTests.controller"
    private var store: KitoSeenStore!

    private let tour = KitoTour("wallet", version: 2, steps: [
        KitoTourStep("balance", title: "Balance", message: "Your money."),
        KitoTourStep("send", title: "Send", message: "Pay anyone.", advancesOnTargetTap: true),
        KitoTourStep("cards", title: "Cards", message: "Freeze a card."),
    ])

    override func setUp() async throws {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        store = KitoSeenStore(defaults: defaults)
    }

    func testRunsOnceThenMarksSeen() {
        let controller = KitoTourController(tour, store: store)
        XCTAssertTrue(controller.startIfNeeded())
        XCTAssertEqual(controller.currentStep?.id, "balance")
        XCTAssertEqual(controller.stepLabel, "Step 1 of 3")
        controller.next()
        controller.next()
        controller.next()
        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(controller.outcome, .completed)
        XCTAssertTrue(controller.hasBeenSeen)
        XCTAssertFalse(controller.startIfNeeded())
        controller.start()
        XCTAssertTrue(controller.isActive, "start() replays a seen tour")
    }

    func testSkipCountsAsSeenAndReportsTheOutcome() {
        let controller = KitoTourController(tour, store: store)
        var outcome: KitoTourOutcome?
        controller.onFinish = { outcome = $0 }
        controller.start()
        controller.skip()
        XCTAssertEqual(outcome, .skipped)
        XCTAssertTrue(controller.hasBeenSeen)
        controller.resetSeen()
        XCTAssertFalse(controller.hasBeenSeen)
    }

    func testStepChangesAreReported() {
        let controller = KitoTourController(tour, store: store)
        var seen: [String] = []
        controller.onStepChange = { seen.append($0.id) }
        controller.start()
        controller.next()
        controller.back()
        controller.go(to: "cards")
        XCTAssertEqual(seen, ["balance", "send", "balance", "cards"])
    }

    func testTappingTheTargetAdvancesOnlyWhenAllowed() {
        let controller = KitoTourController(tour, store: store)
        controller.start()
        controller.targetTapped("balance")
        XCTAssertEqual(controller.currentStep?.id, "balance", "step 1 doesn't advance on tap")
        controller.next()
        controller.targetTapped("cards")
        XCTAssertEqual(controller.currentStep?.id, "send", "a tap on another element is ignored")
        controller.targetTapped("send")
        XCTAssertEqual(controller.currentStep?.id, "cards")
    }

    func testChecklistProgressFollowsCompletedSteps() {
        let controller = KitoTourController(tour, store: store)
        controller.go(to: "send")
        controller.next()
        XCTAssertEqual(controller.checklist.label, "1/3")
        XCTAssertTrue(controller.isCompleted(tour.steps[1]))
        XCTAssertFalse(controller.isCompleted(tour.steps[0]))
    }

    func testANewVersionShowsAgain() {
        let controller = KitoTourController(tour, store: store)
        controller.start()
        controller.finish()
        var updated = tour
        updated.version = 3
        XCTAssertTrue(KitoTourController(updated, store: store).startIfNeeded())
    }
}
