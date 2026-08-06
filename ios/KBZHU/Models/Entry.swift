import Foundation

enum MealKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: return "Завтрак"
        case .lunch: return "Обед"
        case .dinner: return "Ужин"
        case .snack: return "Перекус"
        }
    }

    /// Display order on the diary and in «Куда добавить?».
    static let ordered: [MealKind] = [.breakfast, .lunch, .dinner, .snack]
}

/// One logged portion in the diary.
struct Entry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var foodID: UUID
    var meal: MealKind
    var grams: Double
    /// Start of the day the entry belongs to.
    var day: Date
    var createdAt: Date = Date()
}
