# KitoTour

Product tours for SwiftUI: point at real views with a spotlight that glides and morphs from one
element to the next, a pulsing beacon, a card that follows along, hand-drawn coach marks or a
"Getting started 2/5" checklist. Standalone tooltips that flip to stay on screen, "New" badges
that clear once seen, and a What's New sheet shown once per version. Part of the
[Kito](https://github.com/WykSofts-Inc/KitoDevKit) ecosystem.

## A tour in three steps

```swift
extension KitoTour {
    static let wallet = KitoTour("wallet", version: 1, steps: [
        KitoTourStep("balance", title: "Your balance", message: "Tap to hide it in public.",
                     systemImage: "eye.slash", spotlight: .roundedRect(cornerRadius: 20)),
        KitoTourStep("send", title: "Send money", message: "Pay anyone with their phone number.",
                     systemImage: "paperplane.fill", spotlight: .circle, advancesOnTargetTap: true),
        KitoTourStep("cards", title: "Your cards", message: "Freeze a card in one tap.",
                     systemImage: "creditcard.fill", placement: .top, actionTitle: "Got it"),
    ])
}

struct WalletScreen: View {
    @State private var tour = KitoTourController(.wallet)

    var body: some View {
        ScrollView {
            BalanceCard().kitoTourAnchor("balance")
            SendButton().kitoTourAnchor("send")
            CardsRow().kitoTourAnchor("cards")
        }
        .kitoTour(tour, style: .spotlight)
        .onAppear { tour.startIfNeeded() }        // once per tour version
    }
}
```

Mark views with `.kitoTourAnchor(_:)` anywhere inside the view that has `.kitoTour(…)`, usually
the screen's root. A step whose anchor isn't on screen shows its tip in the middle.

Prefer a binding? `.kitoTour(.wallet, isPresented: $showTour, style: .card)` shows the tour while
the binding is true and sets it back to false when it ends.

## Styles

| Style | What it looks like |
| --- | --- |
| `.spotlight` | Dims the screen; the hole morphs between rounded rect, capsule and circle as it moves; a tooltip with an arrow points at it. |
| `.pulse` | Nothing dimmed, the screen stays usable: a pulsing beacon on the element and a compact tip. |
| `.card` | A card along the bottom (or top, when the element is low) with a notch that slides to point at it. |
| `.coachmark` | A dark overlay, a chalk outline, a handwritten label and an arrow that draws itself. Tap anywhere to continue. |
| `.checklist` | A floating "Getting started 2/5" pill that expands into every step; tap one to be shown where it is. |

Every style takes `tint:`; otherwise it uses the theme's primary colour.

## Steps

```swift
KitoTourStep("scan", anchor: "scan-button",      // anchor defaults to the id
             title: "Scan to pay", message: "Point at any Lipa na M-Pesa QR code.",
             systemImage: "qrcode.viewfinder",    // or image: Image("scan-demo")
             placement: .auto,                    // .top, .bottom, .leading, .trailing
             spotlight: .capsule,                 // .roundedRect(cornerRadius:), .circle
             spotlightPadding: 10,
             actionTitle: "Try it",               // default "Next", "Done" on the last step
             advancesOnTargetTap: true)           // tapping the real button moves on too
```

## The controller

```swift
let tour = KitoTourController(.wallet, store: KitoSeenStore.standard)
tour.start()                 // from the first step, even if seen
tour.startIfNeeded()         // only if this version hasn't been seen
tour.next(); tour.back(); tour.skip(); tour.finish()
tour.go(to: "cards")
tour.currentStep; tour.progress; tour.checklist.label     // "2/5"
tour.onStepChange = { step in scrollProxy.scrollTo(step.anchor) }
tour.onFinish = { outcome in analytics.log(outcome) }     // .completed or .skipped
tour.resetSeen()
```

Finishing or skipping marks the tour's `version` as seen. Bump the version to show a changed tour
again. The steps themselves are a plain value, `KitoTourNavigation`, if you'd rather draw your own.

Tours don't scroll for you: use `onStepChange` with a `ScrollViewReader` to bring an element into
view.

## Tooltips

```swift
Button("Filters", systemImage: "slider.horizontal.3") { … }
    .kitoTooltip(isPresented: $showTip, title: "New filters", message: "Sort by distance and price.",
                 systemImage: "sparkles", placement: .bottom, dismissButtonTitle: "Got it",
                 autoDismiss: .seconds(6))
```

The tip goes on the side asked for when there's room, otherwise it flips, and it stays inside the
screen's safe area, or inside the nearest `.kitoTooltipBounds()`. The arrow keeps pointing at the
view even when the tip is pushed in from an edge. The tip is drawn in an overlay of the view, so
raise the view's `zIndex` if later siblings would cover it.

The placement maths is public:

```swift
let layout = KitoTooltipLayout.solve(target: frame, bubble: size, in: safeArea, placement: .auto)
layout.side; layout.frame; layout.arrowOffset
```

## "New" badges

```swift
Button("Insights", systemImage: "chart.bar.xaxis") { … }
    .kitoFeatureBadge("insights", style: .new)              // or .dot, .label("Beta")

.kitoFeatureBadge("budgets", clearsOn: .afterShown(.seconds(3)))
.kitoFeatureBadge("export", clearsOn: .manually)
KitoFeatureBadge.markSeen("export")
```

Every badge with the same id clears together. Bump `version` to show it again for an updated
feature.

## What's New

```swift
let whatsNew = KitoWhatsNew(version: "2.4", title: "What's new in Pesa", features: [
    KitoWhatsNewFeature("Split bills", message: "Share a bill with friends in two taps.",
                        systemImage: "person.2.fill", tint: .orange),
    KitoWhatsNewFeature("Dark mode", message: "Easy on the eyes at night.", systemImage: "moon.fill"),
])

ContentView()
    .kitoWhatsNew(whatsNew)                            // once per version
    .kitoWhatsNew(whatsNew, isPresented: $showNews)    // or when you choose
```

Versions compare number by number, so "2.10" is newer than "2.9". A version never seen before
counts as new, including on a fresh install; skip the modifier on first launch if you don't want
that.

## Accessibility

Each step moves VoiceOver focus to the tip's title, reads "Step 2 of 5" with it, then the message.
Skip is on every step, and the two-finger scrub gesture skips too. Spotlight, card and coach mark
tours keep VoiceOver inside the tour; pulse and checklist tours leave the screen usable. With
Reduce Motion, the spotlight fades between elements instead of gliding, and beacons stop pulsing.

## Right-to-left

- Tips, the spotlight, beacons, cards and coach-mark arrows land on the right element in Arabic or Hebrew:
  anchor and global frames are physical, so they are converted to layout-direction coordinates before placing anything.
- `.leading` / `.trailing` placements follow reading order: `.leading` puts the tip on the element's right in RTL,
  and the arrow sits on the matching edge.
- Back and Next use `chevron.backward` / `arrow.forward`, so they point the right way.

## Installation

```swift
.package(url: "https://github.com/WykSofts-Inc/KitoTour.git", from: "0.1.0")
```

## License

MIT — see [LICENSE](LICENSE).
