import Foundation

struct Logger {
    static let shared = Logger()
    private let logFileURL: URL
    
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logFileURL = docs.appendingPathComponent("Jarvis_Log.txt")
        
        // Create file if not exists
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }
    
    func log (_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)\n"
        
        print(entry) // Keep console output
        
        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            handle.seekToEndOfFile()
            if let data = entry.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        }
    }
}

// Global helper
func log (_ msg: String) {
    Logger.shared.log(msg)
}

