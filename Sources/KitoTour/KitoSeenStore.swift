//
//  KitoSeenStore.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// The rules for "show once": whether something should be shown again, given the version the
/// user last saw.
public enum KitoSeenRules {
    /// Show a tour or badge when it has never been seen, or when the version seen is older.
    public static func shouldShow(version: Int, lastSeen: Int?) -> Bool {
        guard let lastSeen else { return true }
        return version > lastSeen
    }

    /// Show a What's New sheet when it has never been seen, or when `version` is newer than the
    /// last one seen ("2.10" is newer than "2.9").
    public static func shouldShow(version: String, lastSeen: String?) -> Bool {
        guard let lastSeen else { return true }
        return compare(version, lastSeen) == .orderedDescending
    }

    /// Compares dotted version strings number by number: "2.10" > "2.9", "2.0" == "2", and a
    /// non-numeric part such as "beta" counts as 0.
    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = components(lhs)
        let right = components(rhs)
        for position in 0..<max(left.count, right.count) {
            let a = position < left.count ? left[position] : 0
            let b = position < right.count ? right[position] : 0
            if a != b { return a < b ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    static func components(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: .whitespaces)
            .split(separator: ".")
            .map { part in Int(part.prefix { $0.isNumber }) ?? 0 }
    }
}

/// Remembers which tours, badges and What's New sheets someone has seen, in `UserDefaults`.
///
/// ```swift
/// let store = KitoSeenStore.standard
/// store.hasSeen("tour.home", version: 2)
/// store.markSeen("tour.home", version: 2)
/// store.reset("tour.home")                // show it again
/// ```
public struct KitoSeenStore {
    public let defaults: UserDefaults
    /// Prepended to every key.
    public let prefix: String

    public init(defaults: UserDefaults = .standard, prefix: String = "kito.seen.") {
        self.defaults = defaults
        self.prefix = prefix
    }

    /// `UserDefaults.standard` with the "kito.seen." prefix.
    public static var standard: KitoSeenStore { KitoSeenStore() }

    /// The full `UserDefaults` key for `key`.
    public func storageKey(_ key: String) -> String { prefix + key }

    // MARK: Whole-number versions (tours, badges)

    /// The highest version marked seen, if any.
    public func lastSeenVersion(_ key: String) -> Int? {
        defaults.object(forKey: storageKey(key)) as? Int
    }

    public func hasSeen(_ key: String, version: Int = 1) -> Bool {
        !KitoSeenRules.shouldShow(version: version, lastSeen: lastSeenVersion(key))
    }

    /// Records `version` as seen. Never lowers a version already stored.
    public func markSeen(_ key: String, version: Int = 1) {
        let stored = lastSeenVersion(key) ?? Int.min
        defaults.set(max(stored, version), forKey: storageKey(key))
    }

    // MARK: Dotted versions (What's New)

    public func lastSeenRelease(_ key: String) -> String? {
        defaults.string(forKey: storageKey(key))
    }

    public func hasSeen(_ key: String, release: String) -> Bool {
        !KitoSeenRules.shouldShow(version: release, lastSeen: lastSeenRelease(key))
    }

    /// Records `release` as seen. Never replaces a newer release already stored.
    public func markSeen(_ key: String, release: String) {
        if let stored = lastSeenRelease(key), KitoSeenRules.compare(stored, release) == .orderedDescending { return }
        defaults.set(release, forKey: storageKey(key))
    }

    /// Forgets `key`, so it shows again.
    public func reset(_ key: String) {
        defaults.removeObject(forKey: storageKey(key))
    }

    // MARK: Tours

    public func hasSeen(_ tour: KitoTour) -> Bool { hasSeen(tour.seenKey, version: tour.version) }
    public func markSeen(_ tour: KitoTour) { markSeen(tour.seenKey, version: tour.version) }
    public func reset(_ tour: KitoTour) { reset(tour.seenKey) }
}
