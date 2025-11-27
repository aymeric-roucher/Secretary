import SwiftUI

struct SpotlightView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Status Area (no typing input; typing happens in active app)
            HStack(spacing: 15) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 24))
                    .foregroundColor(appState.isRecording ? .red : .secondary)
                    .frame(width: 30)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            appState.toggleRecording()
                        }
                    }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            // Waveform (Always Visible - Idle or Active)
            WaveformView(recorder: appState.audioRecorder, isRecording: appState.isRecording)
                .frame(height: 60)
                .padding(.bottom, 10)
                .opacity(appState.isRecording ? 1.0 : 0.3)
            
            if appState.isProcessing {
                ProcessingIndicator()
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(appState.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 320)
                .onChange(of: appState.messages.count) { _, _ in
                    if let last = appState.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            
            Text("Press Esc or click outside to close")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .frame(width: 700)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .overlay(alignment: .top) {
            if appState.shortRecordingWarning {
                ShortRecordingToast(message: "The shortcut was pressed too briefly") {
                    withAnimation { appState.shortRecordingWarning = false }
                }
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct MessageBubble: View {
    var message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user {
                Spacer()
                Text(message.content)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(18, corners: [.topLeft, .topRight, .bottomLeft])
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                    .frame(maxWidth: 500, alignment: .trailing)
            } else if message.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.purple)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.ultraThinMaterial))
                
                Text(message.content)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .frame(maxWidth: 500, alignment: .leading)
                Spacer()
            } else if message.role == .tool {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.ultraThinMaterial))
                
                HStack {
                    Text(message.content)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
                .frame(maxWidth: 500, alignment: .leading)
                Spacer()
            } else {
                // System
                Text(message.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 4)
    }
}

// Helper for specific corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct MessageOverlay: View {
    var messages: [ChatMessage]
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(messages) { msg in
                HStack(alignment: .top, spacing: 8) {
                    icon(for: msg)
                    Text(msg.content)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    @ViewBuilder
    private func icon(for msg: ChatMessage) -> some View {
        switch msg.role {
        case .user:
            Image(systemName: "person")
                .foregroundColor(.blue)
        case .assistant:
            Image(systemName: "sparkles")
                .foregroundColor(.purple)
        case .tool:
            Image(systemName: "gearshape.fill")
                .foregroundColor(.orange)
        case .system:
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .all

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let p1 = CGPoint(x: rect.minX, y: rect.minY)
        let p2 = CGPoint(x: rect.maxX, y: rect.minY)
        let p3 = CGPoint(x: rect.maxX, y: rect.maxY)
        let p4 = CGPoint(x: rect.minX, y: rect.maxY)

        let topLeft = corners.contains(.topLeft)
        let topRight = corners.contains(.topRight)
        let bottomLeft = corners.contains(.bottomLeft)
        let bottomRight = corners.contains(.bottomRight)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))

        if topLeft {
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        } else {
            path.addLine(to: p1)
        }

        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))

        if topRight {
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        } else {
            path.addLine(to: p2)
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))

        if bottomRight {
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), radius: radius, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        } else {
            path.addLine(to: p3)
        }

        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))

        if bottomLeft {
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius), radius: radius, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        } else {
            path.addLine(to: p4)
        }

        path.closeSubpath()
        return path
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let all: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct WaveformView: View {
    @ObservedObject var recorder: AudioRecorder
    var isRecording: Bool
    
    // Idle animation state
    @State private var phase: Double = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 3) {
                let totalBars = 40
                let barWidth: CGFloat = 4
                
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
        // Recording Logic
        // Map index 0..39 to levels 0..39
        let levels = recorder.audioLevels
        let mappedIndex = Int(Double(index) / 40.0 * Double(levels.count))
        let rawLevel = (isRecording && mappedIndex < levels.count) ? CGFloat(levels[levels.count - 1 - mappedIndex]) : 0.0
        
        // User request: No threshold at all
        let effectiveLevel = rawLevel
        
        // Idle Logic (Sine wave)
        // User request: "default static, with only a tiny animation"
        let offset = Double(index) * 0.5
        let idleHeight = sin(offset + phase) * 2 + 4 // Very subtle breathing (2 to 6 height)
        
        // Combine
        // User request: "proportional to whatever volume is perceived"
        // scaling rawLevel (0-1) to full height
        let activeHeight = max(4, effectiveLevel * maxHeight)
        
        let height = isRecording ? activeHeight : CGFloat(idleHeight)
        
        // Color
        // Make it vibrant when loud, subtle when quiet
        let activeColor = Color.red.opacity(0.5 + effectiveLevel * 0.5)
        let idleColor = Color.secondary.opacity(0.2)
        let color = isRecording ? activeColor : idleColor
        
        return RoundedRectangle(cornerRadius: width / 2)
            .fill(color)
            .frame(width: width, height: height)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: height)
    }
}

struct ProcessingIndicator: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.9)
            Text("Processing...")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

struct ShortRecordingToast: View {
    var message: String
    var dismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
            
            VStack {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
                
                Spacer()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }
}
