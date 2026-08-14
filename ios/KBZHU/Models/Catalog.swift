import Foundation

/// Общий каталог продуктов: один JSON, который лежит в бандле как стартовый снимок
/// и обновляется по сети. Собирается из `catalog/catalog.csv` скриптом `tools/build_catalog.py`.
struct CatalogFile: Decodable {
    /// Короткий хеш содержимого — меняется, когда меняется таблица.
    var revision: String
    var generatedAt: String?
    var products: [CatalogProduct]

    /// Снимок, вшитый в приложение. Он же — первое наполнение базы на чистой установке.
    static func bundled() -> CatalogFile? {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CatalogFile.self, from: data)
    }
}

struct CatalogProduct: Decodable {
    var id: String
    var name: String
    var manufacturer: String?
    var kcal: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    var defaultGrams: Double?
    var unit: String?
    var unitGrams: Double?
    var barcode: String?
    /// «ресторан» — блюдо сети питания. Пусто — обычная упаковка.
    var kind: String?

    var isVenue: Bool { kind == "ресторан" }

    var foodUnit: FoodUnit? {
        guard let unit, !unit.isEmpty else { return nil }
        return FoodUnit(rawValue: unit)
    }

    private var portionGrams: Double {
        if let defaultGrams, defaultGrams > 0 { return defaultGrams }
        if let unitGrams, unitGrams > 0 { return unitGrams }
        return 100
    }

    /// Новый продукт базы.
    func makeFood() -> Food {
        Food(name: name,
             brand: manufacturer ?? "",
             kcal: kcal, protein: protein, fat: fat, carbs: carbs,
             defaultGrams: portionGrams,
             unit: foodUnit,
             unitWeight: foodUnit == nil ? nil : (unitGrams ?? portionGrams),
             isOwn: false,
             isEdited: false,
             barcode: barcode,
             catalogID: id,
             isRetired: false,
             isVenue: isVenue)
    }

    /// Обновление существующего продукта. Локальный идентификатор и флаги сохраняются,
    /// меняются только данные каталога.
    func applied(to food: Food) -> Food {
        var updated = food
        updated.name = name
        updated.brand = manufacturer ?? ""
        updated.kcal = kcal
        updated.protein = protein
        updated.fat = fat
        updated.carbs = carbs
        updated.defaultGrams = portionGrams
        updated.unit = foodUnit
        updated.unitWeight = foodUnit == nil ? nil : (unitGrams ?? portionGrams)
        updated.barcode = barcode
        updated.catalogID = id
        updated.isRetired = false
        updated.isVenue = isVenue
        return updated
    }
}
