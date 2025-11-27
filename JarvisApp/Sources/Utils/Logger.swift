import Foundation

struct Logger {
    static let shared = Logger()
    private let logFileURL: URL
    
    init() {
        // Log file adjacent to the App Bundle (project root when running from build)
        let appBundlePath = Bundle.main.bundleURL
        let projectRoot = appBundlePath.deletingLastPathComponent()
        logFileURL = projectRoot.appendingPathComponent("Jarvis_Log.txt")
        
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

