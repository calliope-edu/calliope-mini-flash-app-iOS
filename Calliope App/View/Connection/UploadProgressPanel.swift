//
//  UploadProgressPanel.swift
//  Calliope App
//
//  Created by Calliope on 10.07.26.
//  Copyright © 2026 calliope. All rights reserved.
//

import SwiftUI

/// Renders the upload progress UI (compact progress bar → expanded cancel panel)
/// and owns the two-stage expansion animation state.
struct UploadProgressPanel: View {
    @ObservedObject var uploadProgress: UploadViewModel
    var namespace: Namespace.ID

    // Two-stage expansion: stage 1 = background + progress bar (isExpanded),
    // stage 2 = buttons morph out (buttonsVisible), text fades in (textVisible)
    @State private var buttonsVisible: Bool = false
    @State private var textVisible: Bool = false

    // Local copy of the view model's result, so the fill, colour change and icon animate.
    @State private var shownResult: TransferResult?
    // Freezes the indeterminate capsule where it was, so the fill grows out of it.
    @State private var resultDate: Date?
    @State private var iconVisible: Bool = false

    private let animationDuration: Double = 0.2
    private let fillDuration: Double = 0.45



    var body: some View {
        VStack(spacing: buttonsVisible ? 16 : 0) {
            // Stage 2: buttons morph out of the progress bar; text fades in afterwards.
            // This block is only shown after the background has finished expanding (stage 1).
            if buttonsVisible {
                HStack(alignment: .top) {
                    // Plain text – no liquid-glass background
                    Text(NSLocalizedString("Transferring to Calliope", comment: ""))
                        .font(.headline)
                        .foregroundColor(.black)
                        .opacity(textVisible ? 1 : 0)
                        .offset(y: textVisible ? 0 : -6)

                    Spacer()

                    // Cancel and X grouped together at trailing
                    HStack(spacing: 8) {
                        Button {
                            uploadProgress.cancel()
                        } label: {
                            Text(NSLocalizedString("Cancel", comment: ""))
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .modifier(
                                    GlassElementModifier(
                                        id: "cancel",
                                        namespace: namespace,
                                        shape: .capsule,
                                        tintColor: .calliopeRed
                                    )
                                )
                        }

                        Button {
                            startCollapse {
                                withAnimation(.spring(duration: animationDuration)) {
                                    uploadProgress.isExpanded = false
                                }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .resizable().scaledToFit()
                                .frame(width: 12, height: 12)
                                .padding(11)
                                .modifier(
                                    GlassElementModifier(
                                        id: "close",
                                        namespace: namespace,
                                        shape: .circle
                                    )
                                )
                        }
                    }
                }
            }

            // Progress bar - always present, animates size
            Button {
                guard uploadProgress.transferResult == nil else { return }
                withAnimation(.spring()) {
                    uploadProgress.isExpanded.toggle()
                }
            } label: {
                progressBarContent
                    .frame(height: 40)
                    .modifier(
                        GlassElementModifier(
                            id: "progressBar",
                            namespace: namespace,
                            shape: .capsule
                        )
                    )
            }
            .frame(maxWidth: uploadProgress.isExpanded ? .infinity : 200)
            .matchedGeometryEffect(id: "progressBarMorph", in: namespace)
        }
        .padding(uploadProgress.isExpanded ? 20 : 0)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.calliopeYellow)
                .shadow(radius: 10)
                .opacity(uploadProgress.isExpanded ? 1 : 0)
        )
        .frame(maxWidth: 420, alignment: .trailing)
        .animation(.spring(duration: animationDuration), value: uploadProgress.isExpanded)
        .onChange(of: uploadProgress.isExpanded) { newValue in
            if newValue {
                startExpand()
            }
            else {
                withAnimation(.spring()) {
                    buttonsVisible = false
                    textVisible = false
                }
            }
        }
        .onChange(of: uploadProgress.transferResult) { result in
            handleResultChange(result)
        }
        .onAppear {
            // Sync local state if the view appears while already expanded
            if uploadProgress.isExpanded {
                buttonsVisible = true
                textVisible = true
            }
            if let result = uploadProgress.transferResult {
                resultDate = Date()
                shownResult = result
                iconVisible = true
            }
        }
    }

    // MARK: - Progress Bar Content

    var progressBarContent: some View {
        ZStack {
            if uploadProgress.isIndeterminate {
                indeterminateBarContent
            } else {
                determinateBarContent
            }
            resultIcon
        }
    }

    private var fillColor: Color {
        shownResult == .failed ? .calliopeRed : .calliopeGreen
    }

    @ViewBuilder
    private var resultIcon: some View {
        if let shownResult {
            Image(systemName: shownResult == .succeeded ? "checkmark" : "xmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(iconVisible ? 1 : 0.3)
                .opacity(iconVisible ? 1 : 0)
                .id(shownResult)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel(
                    shownResult == .succeeded
                        ? NSLocalizedString("Transfer succeeded", comment: "")
                        : NSLocalizedString("Transfer failed", comment: "")
                )
        }
    }

    /// Determinate bar: green fill grows from left proportional to `progress`, percentage centred.
    private var determinateBarContent: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.calliopeYellow)
                .brightness(0.05)

            GeometryReader { geometry in
                Rectangle()
                    .fill(fillColor)
                    .frame(width: shownResult == nil ? max(geometry.size.width * uploadProgress.progress, 0) : geometry.size.width)
            }

            Text("\(Int(uploadProgress.progress * 100))%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .opacity(shownResult == nil ? 1 : 0)
        }
        .clipShape(Capsule())
    }

    /// Indeterminate bar: a green capsule bounces left-to-right; `statusText` is centred on top.
    private var indeterminateBarContent: some View {
        ZStack {
            Capsule()
                .fill(Color.calliopeYellow)
                .brightness(0.05)

            // TimelineView drives position purely from wall-clock time so it cannot be
            // interrupted by parent spring animations or geometry changes during expansion.
            TimelineView(.animation(minimumInterval: nil, paused: resultDate != nil)) { context in
                GeometryReader { geometry in
                    let capsuleWidth = geometry.size.width * 0.30
                    let maxOffset = geometry.size.width - capsuleWidth
                    let position = bouncePosition(at: resultDate ?? context.date)
                    Capsule()
                        .fill(fillColor)
                        .frame(width: shownResult == nil ? capsuleWidth : geometry.size.width, height: geometry.size.height)
                        .offset(x: shownResult == nil ? CGFloat(position) * maxOffset : 0)
                }
            }

            Text(uploadProgress.statusText)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .opacity(shownResult == nil ? 1 : 0)
        }
        .clipShape(Capsule())
    }

    // 2-second period: 0→1→0 triangle wave, smoothed with easeInOut cubic
    private func bouncePosition(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 2.0) / 2.0
        let linear: Double = t < 0.5 ? t * 2.0 : 2.0 - t * 2.0
        return linear < 0.5
            ? 4.0 * linear * linear * linear
            : 1.0 - pow(-2.0 * linear + 2.0, 3) / 2.0
    }

    // MARK: - Result Animation

    // Folds an expanded panel back into the bar first, then fills the bar.
    private func handleResultChange(_ result: TransferResult?) {
        guard let result else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                shownResult = nil
                resultDate = nil
                iconVisible = false
            }
            return
        }
        if shownResult != nil {
            withAnimation(.easeInOut(duration: fillDuration)) {
                shownResult = result
            }
            return
        }
        guard uploadProgress.isExpanded else {
            showResult(result)
            return
        }
        startCollapse {
            withAnimation(.spring(duration: animationDuration)) {
                uploadProgress.isExpanded = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                guard uploadProgress.transferResult == result, shownResult == nil else { return }
                showResult(result)
            }
        }
    }

    private func showResult(_ result: TransferResult) {
        resultDate = Date()
        withAnimation(.easeInOut(duration: fillDuration)) {
            shownResult = result
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6).delay(fillDuration * 0.6)) {
            iconVisible = true
        }
    }

    // MARK: - Expand Animation (two-stage opening)

    // Sequences: background + progress bar finish expanding (stage 1) → buttons morph
    // out of the progress bar (stage 2) → text fades in after. Called once isExpanded
    // has flipped true (see the progress bar button).
    private func startExpand() {
        // Stage 2 starts once the stage-1 spring has settled.
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.27) {
            guard uploadProgress.isExpanded else { return }
            withAnimation(.spring(duration: animationDuration * 2)) {
                buttonsVisible = true
            }
        }
        // Text fades in mid-way through the button morph.
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.45) {
            guard uploadProgress.isExpanded else { return }
            withAnimation(.easeOut(duration: animationDuration * 0.8)) {
                textVisible = true
            }
        }
    }

    // MARK: - Collapse Animation (inverse of two-stage opening)

    // Sequences: text fades out → buttons merge into progress bar → `done()` is called.
    // For the X button and a finished transfer, `done` collapses the background (stage 1 reverse).
    private func startCollapse(done: @escaping () -> Void) {
        // Step 1: fade out the text first (mirror of the text-fade-in at the end of opening).
        withAnimation(.easeIn(duration: animationDuration * 0.45)) {
            textVisible = false
        }
        // Step 2: merge buttons back into the progress bar (mirror of stage 2).
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.27) {
            withAnimation(.spring(duration: animationDuration * 2)) {
                buttonsVisible = false
            }
        }
        // Step 3: execute the caller's action (collapse background or cancel).
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            done()
        }
    }
}
