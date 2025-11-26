import Foundation

struct Logger {
    static let shared = Logger()
    private let logFileURL: URL
    
    init() {
        // Hardcoded to project root as requested for this dev environment
        logFileURL = URL(fileURLWithPath: "/Users/aymeric/Documents/Code/Jarvis/Jarvis_Log.txt")
        
        // Create file if not exists
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }
    
            func log(_ message: String) {
    
                let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
    
                let entry = "[\(timestamp)] \(message)\n"
    
                
    
                print(entry) // Keep console output
    
                
    
                do {
    
                    // Ensure file exists (create if not)
    
                    if !FileManager.default.fileExists(atPath: logFileURL.path) {
    
                        try "".write(to: logFileURL, atomically: true, encoding: .utf8)
    
                    }
    
                    
    
                    // Open file for appending
    
                    let fileHandle = try FileHandle(forWritingTo: logFileURL)
    
                    fileHandle.seekToEndOfFile()
    
                    if let data = entry.data(using: .utf8) {
    
                        fileHandle.write(data)
    
                    }
    
                    fileHandle.closeFile()
    
                } catch {
    
                    print("CRITICAL LOGGER ERROR: Could not write to log file \(logFileURL.path): \(error)")
    
                }
    
            }
    
        }
    
        
    
        // Global helper
    
        func log(_ msg: String) {
    
            Logger.shared.log(msg)
    
        }

