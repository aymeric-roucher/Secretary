import AppKit

enum SoundPlayer {
    static let soundOptions = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]
    static let defaultStartSound = "Tink"
    static let defaultStopSound = "Pop"

    static func playStart() {
        let sound = UserDefaults.standard.string(forKey: "startSound") ?? defaultStartSound
        play(named: sound)
    }

    static func playStop() {
        let sound = UserDefaults.standard.string(forKey: "stopSound") ?? defaultStopSound
        play(named: sound)
    }

    static func preview(sound: String) {
        play(named: sound)
    }

    private static func play(named name: String) {
        guard let sound = NSSound(named: NSSound.Name(name)) else {
            log("Sound \(name) not found.")
            return
        }
        sound.play()
    }
}
