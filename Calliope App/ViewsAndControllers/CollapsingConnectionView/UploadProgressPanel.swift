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
    @ObservedObject var uploadProgress: UploadProgressViewModel
    var namespace: Namespace.ID

    // Two-stage expansion: stage 1 = background + progress bar (isExpanded),
    // stage 2 = buttons morph out (buttonsVisible), text fades in (textVisible)
    @State private var buttonsVisible: Bool = false
    @State private var textVisible: Bool = false



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
                            startCollapse { uploadProgress.cancel() }
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
                                withAnimation(.spring(duration: 0.55)) {
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
        }
        .padding(uploadProgress.isExpanded ? 20 : 0)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.calliopeYellow)
                .shadow(radius: 10)
                .opacity(uploadProgress.isExpanded ? 1 : 0)
        )
        .frame(maxWidth: 420, alignment: .trailing)
        .animation(.spring(duration: 0.55), value: uploadProgress.isExpanded)
        // Two-stage expansion: when isExpanded flips true, delay the buttons so the
        // background and progress bar finish animating first (stage 1), then morph
        // the buttons out of the progress bar (stage 2) with the text fading in after.
        .onChange(of: uploadProgress.isExpanded) { newValue in
            if newValue {
                // Stage 2 starts once the stage-1 spring (~0.55 s) has settled.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    guard uploadProgress.isExpanded else { return }
                    withAnimation(.spring(duration: 1.1)) {
                        buttonsVisible = true
                    }
                }
                // Text fades in mid-way through the button morph.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    guard uploadProgress.isExpanded else { return }
                    withAnimation(.easeOut(duration: 0.45)) {
                        textVisible = true
                    }
                }
            } else {
                withAnimation(.spring()) {
                    buttonsVisible = false
                    textVisible = false
                }
            }
        }
        .onAppear {
            // Sync local state if the view appears while already expanded
            if uploadProgress.isExpanded {
                buttonsVisible = true
                textVisible = true
            }
        }
    }

    // MARK: - Progress Bar Content

    @ViewBuilder
    var progressBarContent: some View {
        if uploadProgress.isIndeterminate {
            indeterminateBarContent
        } else {
            determinateBarContent
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
                    .fill(Color.calliopeGreen)
                    .frame(width: max(geometry.size.width * uploadProgress.progress, 0))
            }

            Text("\(Int(uploadProgress.progress * 100))%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
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
            TimelineView(.animation) { context in
                GeometryReader { geometry in
                    let capsuleWidth = geometry.size.width * 0.30
                    let maxOffset = geometry.size.width - capsuleWidth
                    // 2-second period: 0→1→0 triangle wave, smoothed with easeInOut cubic
                    let t = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 2.0) / 2.0
                    let linear: Double = t < 0.5 ? t * 2.0 : 2.0 - t * 2.0
                    let eased: Double = linear < 0.5
                        ? 4.0 * linear * linear * linear
                        : 1.0 - pow(-2.0 * linear + 2.0, 3) / 2.0
                    Capsule()
                        .fill(Color.calliopeGreen)
                        .frame(width: capsuleWidth, height: geometry.size.height)
                        .offset(x: CGFloat(eased) * maxOffset)
                }
            }

            Text(uploadProgress.statusText)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
        }
        .clipShape(Capsule())
    }

    // MARK: - Collapse Animation (inverse of two-stage opening)

    // Sequences: text fades out → buttons merge into progress bar → `done()` is called.
    // For the X button, `done` collapses the background (stage 1 reverse).
    // For Cancel, `done` calls cancel() which removes the view entirely.
    private func startCollapse(done: @escaping () -> Void) {
        // Step 1: fade out the text first (mirror of the text-fade-in at the end of opening).
        withAnimation(.easeIn(duration: 0.25)) {
            textVisible = false
        }
        // Step 2: merge buttons back into the progress bar (mirror of stage 2).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(duration: 1.1)) {
                buttonsVisible = false
            }
        }
        // Step 3: execute the caller's action (collapse background or cancel).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            done()
        }
    }
}
