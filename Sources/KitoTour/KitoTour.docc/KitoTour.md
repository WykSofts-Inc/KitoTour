# ``KitoTour``

Product tours, tooltips, feature badges, and a What's New sheet for SwiftUI.

## Overview

KitoTour points at real views in your interface. Describe a tour as a
``KitoTour/KitoTour`` of ``KitoTourStep`` values, mark the matching views with
`kitoTourAnchor(_:)`, and attach a ``KitoTourController`` to the screen's root
with `kitoTour(_:style:tint:)`. A step whose anchor is not on screen shows its
tip in the middle.

```swift
extension KitoTour {
    static let wallet = KitoTour("wallet", version: 1, steps: [
        KitoTourStep("balance", title: "Your balance", message: "Tap to hide it in public.",
                     systemImage: "eye.slash", spotlight: .roundedRect(cornerRadius: 20)),
        KitoTourStep("send", title: "Send money", message: "Pay anyone with their phone number.",
                     systemImage: "paperplane.fill", spotlight: .circle, advancesOnTargetTap: true),
    ])
}

struct WalletScreen: View {
    @State private var tour = KitoTourController(.wallet)

    var body: some View {
        ScrollView {
            BalanceCard().kitoTourAnchor("balance")
            SendButton().kitoTourAnchor("send")
        }
        .kitoTour(tour, style: .spotlight)
        .onAppear { tour.startIfNeeded() }
    }
}
```

``KitoTourStyle`` chooses the presentation: a morphing spotlight, a pulsing
beacon, a card that follows along, hand-drawn coach marks, or a "Getting
started" checklist. Finishing or skipping marks the tour's version as seen in
a ``KitoSeenStore``; bump the version to show a changed tour again. The step
logic is also available as a plain value, ``KitoTourNavigation``, if you would
rather draw your own.

Beyond tours, the package provides standalone tooltips that flip to stay on
screen (`kitoTooltip`), "New" badges that clear once seen
(`kitoFeatureBadge`), and a What's New sheet shown once per version
(`kitoWhatsNew`). Each step moves VoiceOver focus to the tip, and Reduce Motion
replaces gliding and pulsing with fades.

## Topics

### Tours

- ``KitoTour/KitoTour``
- ``KitoTourStep``
- ``KitoTourController``
- ``KitoTourStyle``
- ``KitoTourPlacement``
- ``KitoSpotlightShape``
- ``KitoTourOutcome``

### Custom Tour Presentation

- ``KitoTourNavigation``
- ``KitoChecklistProgress``
- ``KitoSpotlightCutout``
- ``KitoTooltipBubbleShape``
- ``KitoCoachmarkArrowShape``

### Tooltips

- ``KitoTooltipLayout``
- ``KitoTooltipSide``

### Feature Badges

- ``KitoFeatureBadge``
- ``KitoFeatureBadgeStyle``
- ``KitoFeatureBadgeClearing``

### What's New

- ``KitoWhatsNew``
- ``KitoWhatsNewFeature``
- ``KitoWhatsNewView``

### Seen State

- ``KitoSeenStore``
- ``KitoSeenRules``
