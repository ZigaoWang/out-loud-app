import SwiftUI

struct AudioWaveformView: View {
    let audioLevel: Float
    let isRecording: Bool

    private let barCount = 24

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Ambient glow
                RoundedRectangle(cornerRadius: geometry.size.height / 2)
                    .fill(LinearGradient(
                        colors: backgroundColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .opacity(isRecording ? 0.45 : 0.2)
                    .blur(radius: 14)

                // Waveform bars
                HStack(alignment: .center, spacing: geometry.size.width / CGFloat(barCount * 6)) {
                    ForEach(0..<barCount, id: \.self) { index in
                        Capsule()
                            .fill(LinearGradient(
                                colors: barGradient,
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(
                                width: max(CGFloat(3), geometry.size.width / (CGFloat(barCount) * 1.6)),
                                height: barHeight(for: index, in: geometry.size)
                            )
                            .opacity(isRecording ? 0.95 : 0.4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeOut(duration: 0.18), value: audioLevel)

                // Outline for definition
                RoundedRectangle(cornerRadius: geometry.size.height / 2)
                    .strokeBorder(Color.white.opacity(isRecording ? 0.15 : 0.05), lineWidth: 1)
            }
        }
        .frame(height: isRecording ? 88 : 64)
        .overlay(alignment: .top) {
            VStack(spacing: 6) {
                if isRecording {
                    Text(volumeEmphasis)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Capsule())
                        .transition(.opacity)
                } else {
                    Text("Mic paused")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, isRecording ? 12 : 0)
        }
        .padding(.horizontal, isRecording ? 4 : 12)
        .padding(.vertical, 12)
    }

    private func barHeight(for index: Int, in size: CGSize) -> CGFloat {
        let normalizedLevel = max(0.04, min(1.0, CGFloat(audioLevel)))
        let center = CGFloat(barCount - 1) / 2.0
        let distanceFromCenter = abs(CGFloat(index) - center)
        let taper = 1.0 - (distanceFromCenter / center) * 0.75
        let minHeight = size.height * 0.15
        let maxHeight = size.height * 0.95
        let dynamicHeight = minHeight + (maxHeight - minHeight) * normalizedLevel * taper
        return max(minHeight, dynamicHeight)
    }

    private var backgroundColors: [Color] {
        if isRecording {
            return [Color(red: 0.35, green: 0.45, blue: 0.95), Color(red: 0.2, green: 0.85, blue: 0.75)]
        }
        return [Color(.systemGray6), Color(.systemGray5)]
    }

    private var barGradient: [Color] {
        if isRecording {
            return [
                Color.white.opacity(0.95),
                Color(red: 0.4, green: 0.7, blue: 0.95)
            ]
        }
        return [Color(.systemGray4), Color(.systemGray5)]
    }

    private var volumeEmphasis: String {
        switch audioLevel {
        case _ where audioLevel > 0.75:
            return "Crystal clear"
        case _ where audioLevel > 0.45:
            return "Great energy"
        case _ where audioLevel > 0.18:
            return "Keep talking"
        case _ where audioLevel > 0.05:
            return "Lean closer"
        default:
            return "Awaiting voice"
        }
    }
}

struct AudioWaveformView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AudioWaveformView(audioLevel: 0.8, isRecording: true)
                .padding()

            AudioWaveformView(audioLevel: 0.4, isRecording: true)
                .padding()

            AudioWaveformView(audioLevel: 0.1, isRecording: true)
                .padding()

            AudioWaveformView(audioLevel: 0, isRecording: false)
                .padding()
        }
    }
}
