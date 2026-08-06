import Foundation

/// A countable serving unit — «1 ролл», «2 сырника», «0,5 стакана».
enum FoodUnit: String, Codable, CaseIterable, Hashable {
    case piece = "шт"
    case portion = "порция"
    case pack = "пачка"
    case glass = "стакан"
    case jar = "баночка"
    case slice = "ломтик"

    /// [1, 2, 5] forms for pluralisation.
    var forms: [String] {
        switch self {
        case .piece: return ["шт", "шт", "шт"]
        case .portion: return ["порция", "порции", "порций"]
        case .pack: return ["пачка", "пачки", "пачек"]
        case .glass: return ["стакан", "стакана", "стаканов"]
        case .jar: return ["баночка", "баночки", "баночек"]
        case .slice: return ["ломтик", "ломтика", "ломтиков"]
        }
    }

    /// Label of the «count» segment on the product card.
    var modeLabel: String {
        switch self {
        case .piece: return "В штуках"
        case .portion: return "Порциями"
        case .pack: return "Пачками"
        case .glass: return "Стаканами"
        case .jar: return "Баночками"
        case .slice: return "Ломтиками"
        }
    }

    func form(_ count: Double) -> String { Ru.plural(count, forms) }
}

/// A product or dish. Macros are always stored per 100 g, as in the prototype's `DB`.
struct Food: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var brand: String
    var kcal: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    /// Portion suggested when the product is opened.
    var defaultGrams: Double
    var unit: FoodUnit?
    /// Weight of one unit in grams.
    var unitWeight: Double?
    /// User-created dish — lives in «Своя еда», never shown in the shared search.
    var isOwn: Bool = false
    /// The user corrected the nutrition values of a stock product.
    var isEdited: Bool = false
    var barcode: String?

    var gramsPerUnit: Double { unitWeight ?? defaultGrams }

    /// «Nordic · 88 ккал / 100 г · Б 3 Ж 1.7 У 15»
    var listSubtitle: String {
        let prefix = brand.isEmpty ? "" : "\(brand) · "
        return prefix + "\(Int(kcal.rounded())) ккал / 100 г · Б \(Ru.number(protein)) Ж \(Ru.number(fat)) У \(Ru.number(carbs))"
    }

    /// Same line without the brand — used on the «Продукты» screen.
    var nutritionSubtitle: String {
        "\(Int(kcal.rounded())) ккал / 100 г · Б \(Ru.number(protein)) Ж \(Ru.number(fat)) У \(Ru.number(carbs))"
    }

    func nutrition(grams: Double) -> Nutrition {
        let m = grams / 100
        return Nutrition(kcal: kcal * m, protein: protein * m, fat: fat * m, carbs: carbs * m)
    }
}

/// Kcal + macros. Summed all over the app.
struct Nutrition: Hashable {
    var kcal: Double = 0
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0

    static let zero = Nutrition()

    static func + (a: Nutrition, b: Nutrition) -> Nutrition {
        Nutrition(kcal: a.kcal + b.kcal,
                  protein: a.protein + b.protein,
                  fat: a.fat + b.fat,
                  carbs: a.carbs + b.carbs)
    }

    static func += (a: inout Nutrition, b: Nutrition) { a = a + b }

    /// «Б 54 · Ж 10 · У 38»
    var macroLine: String {
        "Б \(Int(protein.rounded())) · Ж \(Int(fat.rounded())) · У \(Int(carbs.rounded()))"
    }
}
