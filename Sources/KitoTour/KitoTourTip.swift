//
//  KitoTourTip.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// The text and buttons inside a tour tip: counter and Skip, artwork, title and message, then
/// progress dots, Back and Next.
struct KitoTourTipContent: View {
    let controller: KitoTourController
    let step: KitoTourStep
    let palette: KitoTourPalette
    var compact = false

    private var theme: KitoTheme { palette.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? theme.spacing.sm : theme.spacing.md) {
            if !compact { header }
            if let image = step.image, !compact { KitoTourHeroImage(image: image, theme: theme) }
            text
            footer
        }
    }

    private var header: some View {
        HStack {
            Text(controller.stepLabel)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(palette.accent)
                .textCase(.uppercase)
                .accessibilityHidden(true)
            Spacer(minLength: theme.spacing.sm)
            KitoTourSkipButton(controller: controller, palette: palette)
        }
    }

    private var text: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            if step.image == nil || compact {
                KitoTourArtwork(step: step, palette: palette, size: compact ? 30 : 38)
            }
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(step.title)
                    .font(compact ? theme.typography.bodyEmphasized : theme.typography.titleMedium)
                    .foregroundStyle(palette.text)
                    .accessibilityLabel("\(controller.stepLabel). \(step.title)")
                    .accessibilityAddTraits(.isHeader)
                    .kitoTourVoiceOverFocus(step.id, announcing: step.message)
                Text(step.message)
                    .font(compact ? theme.typography.label : theme.typography.body)
                    .foregroundStyle(palette.secondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack(spacing: theme.spacing.sm) {
            if compact {
                KitoTourSkipButton(controller: controller, palette: palette)
            } else if let index = controller.currentIndex {
                KitoTourProgressDots(count: controller.stepCount, index: index, palette: palette)
            }
            Spacer(minLength: theme.spacing.sm)
            if !controller.isFirstStep && !compact {
                Button { controller.back() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(KitoTourRoundButtonStyle(palette: palette))
                    .accessibilityLabel("Previous step")
            }
            KitoTourNextButton(controller: controller, step: step, palette: palette)
        }
    }
}

/// "Next", "Done" or the step's own title.
struct KitoTourNextButton: View {
    let controller: KitoTourController
    let step: KitoTourStep
    let palette: KitoTourPalette

    private var title: String {
        step.actionTitle ?? (controller.isLastStep ? "Done" : "Next")
    }

    var body: some View {
        Button { controller.next() } label: {
            HStack(spacing: 6) {
                Text(title)
                if !controller.isLastStep && step.actionTitle == nil {
                    Image(systemName: "arrow.right").font(.caption.weight(.bold))
                }
            }
        }
        .buttonStyle(KitoTourPrimaryButtonStyle(palette: palette))
        .accessibilityHint(controller.isLastStep ? "Ends the tour" : "Shows the next step")
    }
}

/// "Skip tour", reachable on every step.
struct KitoTourSkipButton: View {
    let controller: KitoTourController
    let palette: KitoTourPalette
    var title = "Skip tour"

    var body: some View {
        Button(title) { controller.skip() }
            .font(palette.theme.typography.caption.weight(.semibold))
            .foregroundStyle(palette.secondaryText)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
    }
}

/// Places `content` next to `target` inside `bounds` using `KitoTooltipLayout`, draws the bubble
/// with its arrow, and animates between positions. Everything is in the parent's coordinates.
struct KitoTourCallout<Content: View>: View {
    let target: CGRect?
    let bounds: CGRect
    var placement: KitoTourPlacement = .auto
    var width: CGFloat = 320
    var gap: CGFloat = 14
    var cornerRadius: CGFloat = 22
    let palette: KitoTourPalette
    @ViewBuilder let content: () -> Content

    @State private var size: CGSize = .zero
    /// Off for the first measurement, so the bubble appears in place instead of flying in.
    @State private var ready = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var bubbleWidth: CGFloat { max(160, min(width, bounds.width)) }

    private var layout: KitoTooltipLayout {
        guard let target else { return centred }
        return KitoTooltipLayout.solve(target: target, bubble: size, in: bounds, placement: placement, gap: gap)
    }

    /// With no element to point at, the bubble sits in the middle without an arrow.
    private var centred: KitoTooltipLayout {
        let origin = CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        return KitoTooltipLayout(side: .bottom, frame: CGRect(origin: origin, size: size), arrowOffset: size.width / 2, fits: true)
    }

    private var shape: KitoTooltipBubbleShape {
        KitoTooltipBubbleShape(arrowEdge: target == nil ? nil : layout.arrowEdge,
                               arrowOffset: layout.arrowOffset, cornerRadius: cornerRadius)
    }

    var body: some View {
        let current = layout
        content()
            .padding(palette.theme.spacing.lg)
            .frame(width: bubbleWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background { bubbleBackground }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { measured($0) }
            .opacity(size == .zero ? 0 : 1)
            .position(x: current.frame.midX, y: current.frame.midY)
            .animation(ready ? KitoTourMotion.move(reduceMotion) : nil, value: current)
    }

    private func measured(_ newSize: CGSize) {
        size = newSize
        guard !ready else { return }
        Task { @MainActor in ready = true }
    }

    private var bubbleBackground: some View {
        ZStack {
            shape.fill(palette.surface)
                .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
            shape.stroke(palette.border.opacity(0.7), lineWidth: 0.75)
        }
    }
}
