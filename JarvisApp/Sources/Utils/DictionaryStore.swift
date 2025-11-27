import Foundation

struct DictionaryEntry: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case word
        case correction
    }
    
    let id: UUID
    var kind: Kind
    var input: String
    var output: String?
    
    init(id: UUID = UUID(), kind: Kind, input: String, output: String? = nil) {
        self.id = id
        self.kind = kind
        self.input = input
        self.output = output
    }
}

final class DictionaryStore: ObservableObject {
    @Published private(set) var entries: [DictionaryEntry] = []
    
    private let storageKey = "customDictionaryEntries"
    
    init() {
        load()
    }
    
    func addWord(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = DictionaryEntry(kind: .word, input: trimmed, output: nil)
        entries.append(entry)
        save()
    }
    
    func addCorrection(from: String, to: String) {
        let lhs = from.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lhs.isEmpty, !rhs.isEmpty else { return }
        let entry = DictionaryEntry(kind: .correction, input: lhs, output: rhs)
        entries.append(entry)
        save()
    }

    func update(_ entry: DictionaryEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
            save()
        }
    }
    
    func remove(_ entry: DictionaryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([DictionaryEntry].self, from: data) {
            entries = decoded
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
