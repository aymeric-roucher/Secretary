import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var audioLevels: [Float] = []
    
    private var timer: Timer?
    
    func startRecording() {
        // On macOS, we don't use AVAudioSession in the same way as iOS.
        // We can usually just proceed to record.
        
        do {
            // Setup file path
            let fileURL = getDocumentsDirectory().appendingPathComponent("recording.m4a")
            
            // Settings
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            startMonitoring()
            
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        stopMonitoring()
        return audioRecorder?.url
    }
    
    private var monitoringTask: Task<Void, Never>?

    private func startMonitoring() {
        // Use Task based timer to avoid runloop issues if possible, or just dispatch main
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.audioRecorder?.updateMeters()
            let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
            let level = max(0.0, (power + 160) / 160)
            
            DispatchQueue.main.async {
                if self.audioLevels.count > 20 { self.audioLevels.removeFirst() }
                self.audioLevels.append(level)
            }
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        audioLevels.removeAll()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
