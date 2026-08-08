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

/// Продукт в составе блюда. Название хранится рядом с id, чтобы состав читался,
/// даже если сам продукт из базы потом исчез.
struct FoodPart: Codable, Hashable, Identifiable {
    var id = UUID()
    var foodID: UUID
    var name: String
    var grams: Double
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
    /// Пользователь исправил значения продукта. С этого момента обновления общего
    /// каталога его не трогают — на устройстве остаётся то, что он записал сам.
    var isEdited: Bool = false
    var barcode: String?
    /// Идентификатор в общем каталоге. `nil` — продукт заведён на устройстве.
    var catalogID: String?
    /// Продукт пропал из каталога: в списках не показывается, но старые записи
    /// дневника продолжают на него ссылаться.
    var isRetired: Bool = false
    /// Из чего собрано блюдо. Пусто — КБЖУ задавали руками.
    var parts: [FoodPart] = []

    var isComposed: Bool { !parts.isEmpty }

    /// «Гречка 200 г · Куриная грудка 150 г»
    var partsLine: String {
        parts.map { "\($0.name) \(Ru.number($0.grams)) г" }.joined(separator: " · ")
    }

    var gramsPerUnit: Double { unitWeight ?? defaultGrams }

    /// Читается и старая запись без `catalogID`/`isRetired` — иначе обновление приложения
    /// сделало бы сохранённый файл нечитаемым.
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try box.decode(String.self, forKey: .name)
        brand = try box.decodeIfPresent(String.self, forKey: .brand) ?? ""
        kcal = try box.decodeIfPresent(Double.self, forKey: .kcal) ?? 0
        protein = try box.decodeIfPresent(Double.self, forKey: .protein) ?? 0
        fat = try box.decodeIfPresent(Double.self, forKey: .fat) ?? 0
        carbs = try box.decodeIfPresent(Double.self, forKey: .carbs) ?? 0
        defaultGrams = try box.decodeIfPresent(Double.self, forKey: .defaultGrams) ?? 100
        unit = try box.decodeIfPresent(FoodUnit.self, forKey: .unit)
        unitWeight = try box.decodeIfPresent(Double.self, forKey: .unitWeight)
        isOwn = try box.decodeIfPresent(Bool.self, forKey: .isOwn) ?? false
        isEdited = try box.decodeIfPresent(Bool.self, forKey: .isEdited) ?? false
        barcode = try box.decodeIfPresent(String.self, forKey: .barcode)
        catalogID = try box.decodeIfPresent(String.self, forKey: .catalogID)
        isRetired = try box.decodeIfPresent(Bool.self, forKey: .isRetired) ?? false
        parts = try box.decodeIfPresent([FoodPart].self, forKey: .parts) ?? []
    }

    init(id: UUID = UUID(), name: String, brand: String, kcal: Double, protein: Double,
         fat: Double, carbs: Double, defaultGrams: Double, unit: FoodUnit? = nil,
         unitWeight: Double? = nil, isOwn: Bool = false, isEdited: Bool = false,
         barcode: String? = nil, catalogID: String? = nil, isRetired: Bool = false,
         parts: [FoodPart] = []) {
        self.id = id
        self.name = name
        self.brand = brand
        self.kcal = kcal
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.defaultGrams = defaultGrams
        self.unit = unit
        self.unitWeight = unitWeight
        self.isOwn = isOwn
        self.isEdited = isEdited
        self.barcode = barcode
        self.catalogID = catalogID
        self.isRetired = isRetired
        self.parts = parts
    }

    /// «180 г / порция · 212 ккал / 100 г · Б 16 Ж 14 У 6» — для своей еды,
    /// где важнее вес порции, чем бренд.
    var portionSubtitle: String {
        let prefix = unit.map { "\(Ru.number(gramsPerUnit)) г / \($0.rawValue) · " } ?? ""
        return prefix + "\(Int(kcal.rounded())) ккал / 100 г · Б \(Ru.number(protein)) Ж \(Ru.number(fat)) У \(Ru.number(carbs))"
    }

    /// «Nordic · 88 ккал / 100 г · Б 3 Ж 1.7 У 15»
    var listSubtitle: String {
        let prefix = brand.isEmpty ? "" : "\(brand) · "
        return prefix + "\(Int(kcal.rounded())) ккал / 100 г · Б \(Ru.number(protein)) Ж \(Ru.number(fat)) У \(Ru.number(carbs))"
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
