import AppKit

enum SoundPlayer {
    static func playStart() {
        play(named: "Submarine")
    }
    
    static func playStop() {
        play(named: "Hero")
    }
    
    private static func play(named name: String) {
        guard let sound = NSSound(named: NSSound.Name(name)) else {
            log("Sound \(name) not found.")
            return
        }
        sound.play()
    }
}
