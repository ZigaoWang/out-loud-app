import SwiftUI

struct AudioWaveformView: View {
    let audioLevel: Float
    let isRecording: Bool

    private let barCount = 24

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(
                            width: 3,
                            height: barHeight(for: index, in: geometry.size)
                        )
                        .animation(.easeOut(duration: 0.15), value: audioLevel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

    private var barColor: Color {
        isRecording ? Color(red: 0.32, green: 0.45, blue: 0.91) : Color.gray.opacity(0.3)
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
