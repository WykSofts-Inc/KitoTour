//
//  KitoTourChecklist.swift
//  KitoTour
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A floating "Getting started 2/5" pill that expands into the tour's steps. The current step
/// gets a beacon and a small tip; tapping a row jumps to that step.
struct KitoChecklistTourView: View {
    let controller: KitoTourController
    let step: KitoTourStep?
    let target: CGRect?
    let size: CGSize
    let safe: CGRect
    let palette: KitoTourPalette
    let celebrating: Bool

    @State private var expanded = false
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: KitoTheme { palette.theme }
    private var progress: KitoChecklistProgress {
        celebrating ? KitoChecklistProgress(completed: controller.stepCount, total: controller.stepCount) : controller.checklist
    }

    var body: some View {
        ZStack {
            if let step, !expanded, !celebrating { tip(step) }
            panel
                .frame(width: safe.width, height: safe.height, alignment: .bottomTrailing)
                .position(x: safe.midX, y: safe.midY)
        }
        .animation(KitoTourMotion.pop(reduceMotion), value: expanded)
        .animation(KitoTourMotion.pop(reduceMotion), value: celebrating)
    }

    // MARK: Tip

    private var beacon: CGRect? {
        guard let target else { return nil }
        let diameter = min(max(min(target.width, target.height) + 16, 36), 72)
        return CGRect(x: target.midX - diameter / 2, y: target.midY - diameter / 2, width: diameter, height: diameter)
    }

    @ViewBuilder
    private func tip(_ step: KitoTourStep) -> some View {
        if let beacon {
            KitoPulseBeacon(diameter: beacon.width, color: palette.accent)
                .position(x: beacon.midX, y: beacon.midY)
                .animation(KitoTourMotion.move(reduceMotion), value: beacon)
        }
        KitoTourCallout(target: beacon, bounds: tipBounds, placement: step.placement, width: 270, gap: 10,
                        cornerRadius: 18, palette: palette) {
            KitoTourTipContent(controller: controller, step: step, palette: palette, compact: true)
        }
        .transition(.opacity)
    }

    /// Keeps the tip clear of the pill in the bottom corner.
    private var tipBounds: CGRect {
        CGRect(x: safe.minX, y: safe.minY, width: safe.width, height: max(0, safe.height - 72))
    }

    // MARK: Panel

    @ViewBuilder
    private var panel: some View {
        if expanded && !celebrating {
            list
                .transition(.asymmetric(insertion: .opacity, removal: .opacity))
        } else {
            pill
                .transition(.opacity)
        }
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: expanded ? theme.radii.xl + 6 : 28, style: .continuous)
    }

    private var panelBackground: some View {
        panelShape
            .fill(palette.surface)
            .shadow(color: .black.opacity(0.22), radius: 22, y: 10)
            .overlay(panelShape.stroke(palette.border.opacity(0.7), lineWidth: 0.75))
            .matchedGeometryEffect(id: "panel", in: namespace)
    }

    private var pill: some View {
        Button { expanded = true } label: {
            HStack(spacing: theme.spacing.md) {
                KitoChecklistRing(progress: progress, palette: palette, done: celebrating)
                VStack(alignment: .leading, spacing: 1) {
                    Text(celebrating ? "All done!" : controller.tour.title)
                        .font(theme.typography.label.weight(.semibold))
                        .foregroundStyle(palette.text)
                    Text(celebrating ? "You're all set" : "\(progress.label) complete")
                        .font(theme.typography.caption)
                        .foregroundStyle(palette.secondaryText)
                        .contentTransition(.numericText())
                }
                if !celebrating {
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryText)
                }
            }
            .padding(.leading, theme.spacing.sm)
            .padding(.trailing, theme.spacing.lg)
            .padding(.vertical, theme.spacing.sm)
            .background { panelBackground }
        }
        .buttonStyle(.plain)
        .disabled(celebrating)
        .accessibilityLabel("\(controller.tour.title), \(progress.accessibilityLabel)")
        .accessibilityHint(celebrating ? "" : "Shows the checklist")
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            header
            KitoTourProgressBar(progress: progress.fraction, palette: palette)
            VStack(spacing: theme.spacing.xs) {
                ForEach(Array(controller.tour.steps.enumerated()), id: \.element.id) { index, item in
                    row(item, index: index)
                }
            }
            HStack {
                KitoTourSkipButton(controller: controller, palette: palette, title: "Dismiss checklist")
                Spacer()
            }
        }
        .padding(theme.spacing.lg)
        .frame(width: min(safe.width, 340))
        .background { panelBackground }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: theme.spacing.md) {
            KitoChecklistRing(progress: progress, palette: palette, done: false)
            VStack(alignment: .leading, spacing: 1) {
                Text(controller.tour.title)
                    .font(theme.typography.titleMedium)
                    .foregroundStyle(palette.text)
                    .accessibilityAddTraits(.isHeader)
                Text("\(progress.remaining) left")
                    .font(theme.typography.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            Button { expanded = false } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(KitoTourRoundButtonStyle(palette: palette))
            .accessibilityLabel("Hide checklist")
        }
    }

    private func row(_ item: KitoTourStep, index: Int) -> some View {
        let done = controller.isCompleted(item)
        let current = controller.currentIndex == index
        return Button {
            controller.go(to: item.id)
            expanded = false
        } label: {
            HStack(spacing: theme.spacing.md) {
                KitoChecklistMark(done: done, current: current, palette: palette)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(theme.typography.bodyEmphasized)
                        .foregroundStyle(done ? palette.secondaryText : palette.text)
                        .strikethrough(done, color: palette.secondaryText)
                    Text(item.message)
                        .font(theme.typography.caption)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if let symbol = item.systemImage {
                    Image(systemName: symbol).foregroundStyle(palette.accent).accessibilityHidden(true)
                }
            }
            .padding(theme.spacing.sm)
            .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
                .fill(current ? palette.accent.opacity(0.1) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(done ? "Done" : (current ? "Current step" : "Not done"))
        .accessibilityHint("Shows where it is")
    }
}

/// A ring filling with checklist progress, with the count in the middle.
struct KitoChecklistRing: View {
    let progress: KitoChecklistProgress
    let palette: KitoTourPalette
    let done: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(palette.theme.colors.surfaceMuted, lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress.fraction)
                .stroke(done ? palette.theme.colors.success : palette.accent,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            centre
        }
        .frame(width: 38, height: 38)
        .animation(KitoTourMotion.move(reduceMotion), value: progress)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var centre: some View {
        if done {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(palette.theme.colors.success)
                .symbolEffect(.bounce, value: done)
        } else {
            Text("\(progress.completed)")
                .font(palette.theme.typography.label.weight(.bold).monospacedDigit())
                .foregroundStyle(palette.text)
                .contentTransition(.numericText())
        }
    }
}

/// A row's check circle: filled when done, ringed in the accent when current.
struct KitoChecklistMark: View {
    let done: Bool
    let current: Bool
    let palette: KitoTourPalette

    var body: some View {
        ZStack {
            Circle()
                .stroke(current ? palette.accent : palette.border, lineWidth: 2)
            if done {
                Circle().fill(palette.theme.colors.success)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}
