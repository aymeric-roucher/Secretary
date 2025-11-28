import SwiftUI

struct WaveformView: View {
    @ObservedObject var recorder: AudioRecorder
    var isRecording: Bool
    
    @State private var phase: Double = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 3) {
                let totalBars = 30
                let barWidth: CGFloat = 3
                
                ForEach(0..<totalBars, id: \.self) { index in
                    bar(index: index, width: barWidth, maxHeight: geometry.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
    
    func bar(index: Int, width: CGFloat, maxHeight: CGFloat) -> some View {
        let levels = recorder.audioLevels

        // Waves propagate left to right: newest data on left (index 0), oldest on right
        let sampleIndex = levels.count - 1 - index
        let rawLevel: CGFloat = (isRecording && sampleIndex >= 0 && sampleIndex < levels.count)
            ? CGFloat(levels[sampleIndex])
            : 0.0
        let effectiveLevel = rawLevel > 0.01 ? rawLevel : 0.0

        let offset = Double(index) * 0.5
        let idleHeight = sin(offset + phase) * 4 + 8

        let activeHeight = max(5, effectiveLevel * maxHeight * 0.9)
        let height = isRecording ? activeHeight : CGFloat(idleHeight)

        let color = Theme.textColor.opacity(0.6 + effectiveLevel * 0.4)

        return RoundedRectangle(cornerRadius: width / 2)
            .fill(color)
            .frame(width: width, height: height)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: height)
    }
}
