import SwiftUI

struct LogsView: View {
    @State private var logContent: String = "Loading logs..."
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Logs")
                .font(.custom("Georgia", size: 28))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            let appBundlePath = Bundle.main.bundleURL
            let projectRoot = appBundlePath.deletingLastPathComponent()
            let logPath = projectRoot.appendingPathComponent("Jarvis_Log.txt").path

            Text(logPath)
                .font(.custom("Georgia", size: 12))
                .foregroundColor(.gray)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .textSelection(.enabled)

            ScrollView {
                Text(logContent)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.black)
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(white: 0.97))
            .overlay(Rectangle().stroke(Color(white: 0.85), lineWidth: 1))
            .padding(.horizontal, 24)

            HStack {
                Spacer()
                Button("Clear Logs", action: clearLogs)
                    .font(.custom("Georgia", size: 13))
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color.white)
        .onAppear { loadLogs() }
        .onReceive(timer) { _ in loadLogs() }
    }
    
    func loadLogs() {
        let appBundlePath = Bundle.main.bundleURL
        let projectRoot = appBundlePath.deletingLastPathComponent()
        let logFile = projectRoot.appendingPathComponent("Jarvis_Log.txt")
        
        if let content = try? String(contentsOf: logFile) {
            logContent = content
        } else {
            logContent = "No logs found."
        }
    }
    
    func clearLogs() {
        let appBundlePath = Bundle.main.bundleURL
        let projectRoot = appBundlePath.deletingLastPathComponent()
        let logFile = projectRoot.appendingPathComponent("Jarvis_Log.txt")
        
        try? "".write(to: logFile, atomically: true, encoding: .utf8)
        loadLogs()
    }
}
