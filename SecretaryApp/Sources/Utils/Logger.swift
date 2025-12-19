import Foundation

struct Logger {
    static let shared = Logger()
    static let projectRoot = Bundle.main.bundleURL.deletingLastPathComponent()
    private let logFileURL: URL

    init() {
        logFileURL = Logger.projectRoot.appendingPathComponent("Secretary_Log.txt")
        
        // Ensure file exists (create if not)
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            do {
                try "".write(to: logFileURL, atomically: true, encoding: .utf8)
            } catch {
                print("CRITICAL LOGGER ERROR: Could not create log file at \(logFileURL.path): \(error)")
            }
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

