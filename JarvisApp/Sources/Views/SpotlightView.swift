import SwiftUI

struct SpotlightView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText: String = ""
    
    var body: some View {
        ZStack {
            // Main Background Pill
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            
            VStack(spacing: 0) {
                // Input & Status Area
                HStack(spacing: 15) {
                    // Dynamic Icon / Waveform
                    ZStack {
                        if appState.isRecording {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: 30)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            appState.toggleRecording()
                        }
                    }
                    
                    // Text Input
                    TextField("Ask Jarvis...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22, weight: .light))
                        .padding(.vertical, 16)
                        .onSubmit {
                            // Handle text submission if needed
                        }
                    
                    // Clear Button
                    if !inputText.isEmpty {
                        Button(action: { inputText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                
                // Waveform (Always Visible - Idle or Active)
                WaveformView(levels: appState.audioRecorder.audioLevels, isRecording: appState.isRecording)
                    .frame(height: 60)
                    .padding(.bottom, 10)
                    .opacity(appState.transcript.isEmpty || appState.transcript == "Ready" || appState.isRecording ? 1.0 : 0.3) // Dim when showing result text
                
                // Transcript / Result Area
                if !appState.transcript.isEmpty && appState.transcript != "Ready" && !appState.isRecording {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    ScrollView {
                        Text(appState.transcript)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .lineSpacing(4)
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
        .frame(width: 700)
        .padding(20) // Window margin for shadow
        // Note: Notification listener moved to AppState
    }
}

struct WaveformView: View {
    var levels: [Float]
    var isRecording: Bool
    
    // Idle animation state
    @State private var phase: Double = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 4) {
                let totalBars = 30
                let barWidth = (geometry.size.width - CGFloat(totalBars - 1) * 4) / CGFloat(totalBars)
                
                ForEach(0..<totalBars, id: \.self) { index in
                    bar(index: index, width: barWidth, maxHeight: geometry.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
    
    func bar(index: Int, width: CGFloat, maxHeight: CGFloat) -> some View {
        // Recording Logic
        let levelIndex = levels.count - 1 - index
        let rawLevel = (isRecording && levelIndex >= 0 && levelIndex < levels.count) ? CGFloat(levels[levelIndex]) : 0.0
        
        // Idle Logic (Sine wave)
        let idleHeight = sin(Double(index) * 0.5 + phase) * 10 + 15
        
        // Combine: If recording, use level (amplified), else use idle wave
        let activeHeight = max(4, rawLevel * maxHeight * 1.5)
        let height = isRecording ? activeHeight : CGFloat(idleHeight)
        
        // Color
        let color = isRecording 
            ? Color.red.opacity(0.8) 
            : Color.primary.opacity(0.2 + (Double(height) / Double(maxHeight) * 0.5))
        
        return RoundedRectangle(cornerRadius: width / 2)
            .fill(color)
            .frame(width: width, height: height)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: height)
    }
}
