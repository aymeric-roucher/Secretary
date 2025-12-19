import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    static let waveformBarCount = 30

    var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var audioLevels: [Float] = []
    private(set) var lastRecordingDuration: TimeInterval = 0

    private var timer: Timer?
    
    func startRecording() {
        log("Attempting to start recording.")
        lastRecordingDuration = 0
        
        // 1. Check Microphone Permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            log("Microphone access authorized.")
        case .notDetermined:
            log("Microphone access not determined, requesting...")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted {
                        log("Microphone access granted after request. Retrying start recording.")
                        self.startRecording() // Retry recording after permission granted
                    } else {
                        log("Microphone access denied after request.")
                        self.isRecording = false
                    }
                }
            }
            return // Exit and wait for permission callback
        case .denied, .restricted:
            log("Microphone access denied or restricted. Cannot record.")
            isRecording = false
            return
        @unknown default:
            log("Unknown microphone authorization status.")
            isRecording = false
            return
        }
        
        // 2. Proceed with recording if authorized
        do {
            let projectRoot = Bundle.main.bundleURL.deletingLastPathComponent()
            let recordingsDir = projectRoot.appendingPathComponent("recordings")
            try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)

            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let fileURL = recordingsDir.appendingPathComponent("\(timestamp).m4a")
            log("Recording to file: \(fileURL.path)")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100, // Reasonable quality for STT
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: 128000 // Added bit rate
            ]
            
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.delegate = self // Set delegate for events
            
            if audioRecorder?.record() == true {
                isRecording = true
                log("AudioRecorder started recording successfully.")
                startMonitoring()
            } else {
                log("AudioRecorder failed to start recording.")
                isRecording = false
            }
            
        } catch {
            log("Failed to start audio recording: \(error.localizedDescription)")
            isRecording = false
        }
    }
    
    func stopRecording() -> URL? {
        log("Attempting to stop recording.")
        lastRecordingDuration = audioRecorder?.currentTime ?? 0
        audioRecorder?.stop()
        isRecording = false
        stopMonitoring()
        if let url = audioRecorder?.url {
            log("AudioRecorder stopped. Recorded file: \(url.lastPathComponent)")
            return url
        } else {
            log("AudioRecorder stopped, but no URL found.")
            return nil
        }
    }
    
    private var monitoringTask: Task<Void, Never>?

    private func startMonitoring() {
        log("Starting audio level monitoring.")
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.audioRecorder?.updateMeters()
            let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
            
            // Convert dB to linear amplitude (0.0 to 1.0)
            // -160dB is silence, 0dB is max
            // Simple approximation: normalize -60dB (noise floor) to 0dB
            let minDb: Float = -60.0
            
            var level: Float = 0.0
            if power < minDb {
                level = 0.0
            } else if power >= 0.0 {
                level = 1.0
            } else {
                // Linearize
                level = (power - minDb) / (0.0 - minDb)
            }
            
            DispatchQueue.main.async {
                if self.audioLevels.count > Self.waveformBarCount { self.audioLevels.removeFirst() }
                self.audioLevels.append(level)
            }
        }
    }
    
    private func stopMonitoring() {
        log("Stopping audio level monitoring.")
        timer?.invalidate()
        timer = nil
        audioLevels.removeAll()
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        log("audioRecorderDidFinishRecording successfully: \(flag)")
        if !flag {
            log("Recording finished unsuccessfully.")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        log("audioRecorderEncodeErrorDidOccur: \(error?.localizedDescription ?? "Unknown error")")
    }
}
