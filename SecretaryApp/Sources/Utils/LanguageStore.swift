import Foundation

struct Language: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var code: String  // ISO-639-1 code (e.g., "en", "fr")
    var name: String  // Display name (e.g., "English", "French")

    init(id: UUID = UUID(), code: String, name: String) {
        self.id = id
        self.code = code
        self.name = name
    }

    static let allLanguages: [Language] = [
        Language(code: "en", name: "English"),
        Language(code: "fr", name: "French"),
        Language(code: "es", name: "Spanish"),
        Language(code: "de", name: "German"),
        Language(code: "it", name: "Italian"),
        Language(code: "pt", name: "Portuguese"),
        Language(code: "nl", name: "Dutch"),
        Language(code: "pl", name: "Polish"),
        Language(code: "ru", name: "Russian"),
        Language(code: "ja", name: "Japanese"),
        Language(code: "ko", name: "Korean"),
        Language(code: "zh", name: "Chinese"),
        Language(code: "ar", name: "Arabic"),
        Language(code: "hi", name: "Hindi"),
        Language(code: "tr", name: "Turkish"),
        Language(code: "sv", name: "Swedish"),
        Language(code: "da", name: "Danish"),
        Language(code: "no", name: "Norwegian"),
        Language(code: "fi", name: "Finnish"),
        Language(code: "he", name: "Hebrew"),
        Language(code: "uk", name: "Ukrainian"),
        Language(code: "cs", name: "Czech"),
        Language(code: "el", name: "Greek"),
        Language(code: "ro", name: "Romanian"),
        Language(code: "hu", name: "Hungarian"),
        Language(code: "th", name: "Thai"),
        Language(code: "vi", name: "Vietnamese"),
        Language(code: "id", name: "Indonesian"),
        Language(code: "ms", name: "Malay"),
        Language(code: "ca", name: "Catalan"),
    ]

    static func find(byCode code: String) -> Language? {
        allLanguages.first { $0.code == code }
    }
}

final class LanguageStore: ObservableObject {
    @Published private(set) var selectedLanguages: [Language] = []

    private let storageKey = "selectedLanguages"

    static let defaultLanguages: [Language] = [
        Language(code: "en", name: "English"),
        Language(code: "fr", name: "French")
    ]

    init() {
        load()
    }

    func add(_ language: Language) {
        guard !selectedLanguages.contains(where: { $0.code == language.code }) else { return }
        selectedLanguages.append(language)
        save()
    }

    func remove(_ language: Language) {
        selectedLanguages.removeAll { $0.code == language.code }
        save()
    }

    func replace(at index: Int, with language: Language) {
        guard index >= 0 && index < selectedLanguages.count else { return }
        // Check if the new language is already in the list at a different position
        if let existingIndex = selectedLanguages.firstIndex(where: { $0.code == language.code }), existingIndex != index {
            // Swap them
            selectedLanguages.swapAt(index, existingIndex)
        } else {
            selectedLanguages[index] = language
        }
        save()
    }

    func setLanguages(_ languages: [Language]) {
        selectedLanguages = languages
        save()
    }

    /// Returns comma-separated ISO-639-1 codes for the Whisper API
    var languageCodes: [String] {
        selectedLanguages.map { $0.code }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            // First launch: use defaults
            selectedLanguages = Self.defaultLanguages
            save()
            return
        }
        if let decoded = try? JSONDecoder().decode([Language].self, from: data) {
            selectedLanguages = decoded.isEmpty ? Self.defaultLanguages : decoded
        } else {
            selectedLanguages = Self.defaultLanguages
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(selectedLanguages) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}