import SwiftUI

struct VoiceTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    let onResult: (ParsedVoiceTransaction) -> Void

    private let service = SpeechTransactionService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()

                VStack(spacing: FTSpacing.xl) {
                    Spacer()

                    // Transcript or prompt
                    VStack(spacing: FTSpacing.sm) {
                        if service.permissionDenied {
                            Label("Microphone access denied", systemImage: "mic.slash.fill")
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.expense)
                            Text("Go to Settings → Privacy → Microphone to enable access.")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                                .multilineTextAlignment(.center)
                        } else if !service.transcript.isEmpty {
                            Text(service.transcript)
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textPrimary)
                                .multilineTextAlignment(.center)
                                .animation(.easeInOut(duration: 0.2), value: service.transcript)
                        } else if service.isListening {
                            Text("Listening…")
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.accent)
                        } else {
                            Text("Say something like:\n\"Spent 45 dirhams at Carrefour\"")
                                .font(.ftBody)
                                .foregroundStyle(FTColor.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, FTSpacing.screen)

                    // Waveform while listening
                    if service.isListening {
                        WaveformView()
                    } else {
                        Color.clear.frame(height: 60)
                    }

                    // Mic button
                    Button {
                        if service.isListening {
                            service.stopListening()
                        } else {
                            Task {
                                let granted = await service.requestPermission()
                                guard granted else { return }
                                try? service.startListening()
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(service.isListening ? AnyShapeStyle(FTColor.expense.opacity(0.9)) : AnyShapeStyle(FTColor.accentGradient))
                                .frame(width: 96, height: 96)
                                .shadow(
                                    color: service.isListening
                                        ? FTColor.expense.opacity(0.4)
                                        : FTColor.accentDeep.opacity(0.4),
                                    radius: 24
                                )

                            Image(systemName: service.isListening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .scaleEffect(service.isListening ? 1.08 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: service.isListening)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(service.isListening ? "Stop listening" : "Start voice input")

                    // Parsed result card
                    if let result = service.parsedResult, !service.isListening {
                        ParsedResultCard(result: result)
                            .transition(.move(edge: .bottom).combined(with: .opacity))

                        Button("Use This Transaction") {
                            onResult(result)
                            dismiss()
                        }
                        .buttonStyle(.ftPrimary)
                        .padding(.horizontal, FTSpacing.screen)
                        .transition(.opacity)
                    }

                    Spacer()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: service.parsedResult?.title)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Voice Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        service.stopListening()
                        dismiss()
                    }
                }
                if service.parsedResult == nil && !service.transcript.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Retry") {
                            Task {
                                let granted = await service.requestPermission()
                                guard granted else { return }
                                try? service.startListening()
                            }
                        }
                        .foregroundStyle(FTColor.accent)
                    }
                }
            }
            .onDisappear {
                service.stopListening()
            }
        }
    }
}

// MARK: - Waveform Animation

struct WaveformView: View {
    @State private var phase = false
    @State private var heights: [CGFloat] = (0..<9).map { _ in CGFloat.random(in: 0.3...1.0) }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<9, id: \.self) { i in
                Capsule()
                    .fill(FTColor.accent.opacity(0.7 + 0.3 * heights[i]))
                    .frame(width: 4, height: phase ? heights[i] * 44 + 8 : 8)
                    .animation(
                        .easeInOut(duration: 0.45 + Double(i) * 0.07)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.07),
                        value: phase
                    )
            }
        }
        .frame(height: 60)
        .onAppear { phase = true }
    }
}

// MARK: - Parsed Result Card

struct ParsedResultCard: View {
    let result: ParsedVoiceTransaction

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("PARSED TRANSACTION")
                .font(.ftLabel).tracking(1.4)
                .foregroundStyle(FTColor.textSecondary)

            VStack(spacing: 0) {
                if let amount = result.amount {
                    parsedRow(
                        label: "Amount",
                        value: amount.formatted(as: result.currency ?? "AED"),
                        icon: "dollarsign.circle"
                    )
                    Divider().padding(.leading, 52)
                }
                parsedRow(label: "Title", value: result.title, icon: "text.alignleft")
                Divider().padding(.leading, 52)
                parsedRow(label: "Type", value: result.type.rawValue, icon: result.type.icon)
                Divider().padding(.leading, 52)
                parsedRow(label: "Category", value: result.category.rawValue, icon: result.category.icon)
                if let merchant = result.merchant {
                    Divider().padding(.leading, 52)
                    parsedRow(label: "Merchant", value: merchant, icon: "storefront")
                }
                if let currency = result.currency {
                    Divider().padding(.leading, 52)
                    parsedRow(label: "Currency", value: currency, icon: "globe")
                }
            }
            .background(Color(UIColor.tertiarySystemBackground), in: .rect(cornerRadius: FTRadius.sm))
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
        .padding(.horizontal, FTSpacing.screen)
    }

    private func parsedRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: FTSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(FTColor.accent)
                .frame(width: 28)
            Text(label)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textSecondary)
            Spacer()
            Text(value)
                .font(.ftCallout)
                .foregroundStyle(FTColor.textPrimary)
        }
        .padding(.horizontal, FTSpacing.md)
        .padding(.vertical, 10)
    }
}
