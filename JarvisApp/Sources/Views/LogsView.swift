import SwiftUI

struct LogsView: View {
    @State private var logContent: String = "Loading logs..."
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent Activity")
                .font(.title2)
                .padding(.top)
                .padding(.horizontal)
            
            let appBundlePath = Bundle.main.bundleURL
            let projectRoot = appBundlePath.deletingLastPathComponent()
            let logPath = projectRoot.appendingPathComponent("Jarvis_Log.txt").path
            
            Text("Logs at: \(logPath)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .textSelection(.enabled)
            
            ScrollView {
                Text(logContent)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            
            HStack {
                Spacer()
                Button("Clear Logs", action: clearLogs)
            }
            .padding()
        }
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
