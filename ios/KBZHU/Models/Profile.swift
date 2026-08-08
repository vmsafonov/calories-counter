import Foundation

enum Sex: String, Codable, CaseIterable {
    case female = "f"
    case male = "m"

    var title: String { self == .female ? "Женский" : "Мужской" }
    var short: String { self == .female ? "Ж" : "М" }
}

enum Activity: String, Codable, CaseIterable {
    case low, mid, high

    var title: String {
        switch self {
        case .low: return "Низкая"
        case .mid: return "Средняя"
        case .high: return "Высокая"
        }
    }

    /// Mifflin–St Jeor activity factor.
    var factor: Double {
        switch self {
        case .low: return 1.2
        case .mid: return 1.375
        case .high: return 1.55
        }
    }
}

enum GoalKind: String, Codable, CaseIterable {
    case lose, keep, gain

    var title: String {
        switch self {
        case .lose: return "Похудеть"
        case .keep: return "Поддерживать вес"
        case .gain: return "Набрать массу"
        }
    }

    /// Shorter label for the three-chip row on «Параметры и цель».
    var chipTitle: String {
        switch self {
        case .lose: return "Похудеть"
        case .keep: return "Поддерживать"
        case .gain: return "Набрать массу"
        }
    }

    var subtitle: String {
        switch self {
        case .lose: return "Дефицит 15%, больше белка"
        case .keep: return "Норма по расходу"
        case .gain: return "Профицит 10%"
        }
    }

    var profileSubtitle: String { "Цель: " + title.lowercased() }

    var calorieFactor: Double {
        switch self {
        case .lose: return 0.85
        case .keep: return 1
        case .gain: return 1.1
        }
    }

    var proteinPerKg: Double { self == .lose ? 1.8 : 1.6 }

    var calcNote: String {
        switch self {
        case .lose: return "Дефицит 15% — это примерно 0,5 кг в неделю. Безопасный темп."
        case .gain: return "Профицит 10% — примерно +0,3 кг в неделю."
        case .keep: return "Норма на поддержание веса, без дефицита."
        }
    }
}

struct BodyProfile: Codable, Hashable {
    var sex: Sex = .female
    var age: Int = 29
    var height: Int = 168
    var weight: Int = 64
    var activity: Activity = .mid

    /// «Ж · 29 лет · 168 см · 64 кг»
    var summary: String {
        "\(sex.short) · \(age) \(Ru.years(age)) · \(height) см · \(weight) кг"
    }
}

/// Норма, действующая с определённой даты. Прошедшие дни считаются по той норме,
/// которая была в силе тогда, а не по сегодняшней.
struct GoalsPeriod: Codable, Hashable {
    /// Начало дня, с которого норма действует.
    var effectiveFrom: Date
    var goals: Goals
}

struct Goals: Codable, Hashable {
    var kcal: Int = 1850
    var protein: Int = 120
    var fat: Int = 60
    var carbs: Int = 200

    static func calculated(body: BodyProfile, goal: GoalKind) -> Goals {
        // Mifflin–St Jeor + activity factor, exactly as the prototype computes it.
        let bmr = 10 * Double(body.weight)
            + 6.25 * Double(body.height)
            - 5 * Double(body.age)
            + (body.sex == .male ? 5 : -161)
        let tdee = bmr * body.activity.factor
        let kcal = Int((tdee * goal.calorieFactor / 10).rounded()) * 10
        let protein = Int((Double(body.weight) * goal.proteinPerKg).rounded())
        let fat = Int((Double(body.weight) * 0.9).rounded())
        let carbs = max(60, Int(((Double(kcal - protein * 4 - fat * 9)) / 4).rounded()))
        return Goals(kcal: kcal, protein: protein, fat: fat, carbs: carbs)
    }

    /// «1 570 ккал · Б 115 · Ж 58 · У 175»
    var summaryLine: String {
        "\(Ru.grouped(kcal)) ккал · Б \(protein) · Ж \(fat) · У \(carbs)"
    }
}
