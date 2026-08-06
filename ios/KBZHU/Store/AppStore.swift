import Foundation
import SwiftUI

/// Single source of truth. Owns the persisted document and every mutation on it.
/// Lives on the main thread: every mutation comes from a SwiftUI callback, and disk writes
/// are handed to `ioQueue`.
final class AppStore: ObservableObject {

    @Published private(set) var data: AppData {
        didSet { scheduleSave() }
    }

    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "kbzhu.store.io", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    // MARK: - Lifecycle

    init(fileURL: URL? = nil) {
        let url = fileURL ?? AppStore.defaultFileURL()
        self.fileURL = url
        self.data = AppStore.load(from: url)
    }

    private static func defaultFileURL() -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true))
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("KBZHU", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("appdata.json")
    }

    private static func load(from url: URL) -> AppData {
        guard let raw = try? Data(contentsOf: url) else { return .initial }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AppData.self, from: raw)
        } catch {
            // Never silently discard user data: keep the unreadable file next to the new one.
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("appdata-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return .initial
        }
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = data
        let url = fileURL
        let work = DispatchWorkItem {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let encoded = try? encoder.encode(snapshot) else { return }
            try? encoded.write(to: url, options: .atomic)
        }
        saveWorkItem = work
        ioQueue.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    /// Flush immediately — called when the app leaves the foreground.
    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        let snapshot = data
        let url = fileURL
        ioQueue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let encoded = try? encoder.encode(snapshot) else { return }
            try? encoded.write(to: url, options: .atomic)
        }
    }

    // MARK: - Reading

    var goals: Goals { data.goals }
    var bodyProfile: BodyProfile { data.bodyProfile }
    var goal: GoalKind { data.goal }
    var userName: String { data.userName }
    var didOnboard: Bool { data.didOnboard }
    var showRemaining: Bool { data.showRemaining }

    var ownFoods: [Food] { data.foods.filter { $0.isOwn && !$0.isRetired } }
    var baseFoods: [Food] { data.foods.filter { !$0.isOwn && !$0.isRetired } }

    var catalogETag: String? { data.catalogETag }
    var catalogCheckedAt: Date? { data.catalogCheckedAt }
    var catalogRevision: String? { data.catalogRevision }

    func food(_ id: UUID) -> Food? { data.foods.first { $0.id == id } }
    func food(named name: String) -> Food? { data.foods.first { $0.name == name } }

    func entries(on day: Date) -> [Entry] {
        data.entries
            .filter { Cal.isSameDay($0.day, day) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func entries(on day: Date, meal: MealKind) -> [Entry] {
        entries(on: day).filter { $0.meal == meal }
    }

    func nutrition(of entry: Entry) -> Nutrition {
        food(entry.foodID)?.nutrition(grams: entry.grams) ?? .zero
    }

    func totals(on day: Date) -> Nutrition {
        entries(on: day).reduce(Nutrition.zero) { $0 + nutrition(of: $1) }
    }

    func totals(on day: Date, meal: MealKind) -> Nutrition {
        entries(on: day, meal: meal).reduce(Nutrition.zero) { $0 + nutrition(of: $1) }
    }

    func kcal(on day: Date) -> Int { Int(totals(on: day).kcal.rounded()) }

    func hasEntries(on day: Date) -> Bool {
        data.entries.contains { Cal.isSameDay($0.day, day) }
    }

    /// Consecutive days with at least one entry, ending today (or yesterday if today is empty).
    var streakDays: Int {
        var count = 0
        var cursor = Cal.today
        if !hasEntries(on: cursor) {
            cursor = Cal.adding(days: -1, to: cursor)
            guard hasEntries(on: cursor) else { return 0 }
        }
        while hasEntries(on: cursor) {
            count += 1
            cursor = Cal.adding(days: -1, to: cursor)
        }
        return count
    }

    /// Products the user logged most recently, newest first.
    func recentFoods(limit: Int = 12) -> [Food] {
        var seen = Set<UUID>()
        var result: [Food] = []
        for entry in data.entries.sorted(by: { $0.createdAt > $1.createdAt }) {
            guard !seen.contains(entry.foodID), let food = food(entry.foodID) else { continue }
            seen.insert(entry.foodID)
            result.append(food)
            if result.count >= limit { break }
        }
        return result
    }

    // MARK: - Diary mutations

    @discardableResult
    func addEntry(foodID: UUID, meal: MealKind, grams: Double, day: Date) -> Entry {
        let entry = Entry(foodID: foodID, meal: meal, grams: grams, day: Cal.startOfDay(day))
        data.entries.append(entry)
        return entry
    }

    func updateGrams(entryID: UUID, grams: Double) {
        guard let index = data.entries.firstIndex(where: { $0.id == entryID }) else { return }
        data.entries[index].grams = grams
    }

    func delete(entryID: UUID) {
        data.entries.removeAll { $0.id == entryID }
    }

    /// Copies every entry of `source` into `target`, keeping meals and portions.
    func copyDay(from source: Date, to target: Date) {
        let copies = entries(on: source).map {
            Entry(foodID: $0.foodID, meal: $0.meal, grams: $0.grams, day: Cal.startOfDay(target))
        }
        data.entries.append(contentsOf: copies)
    }

    // MARK: - Food mutations

    /// Values as typed in the food form: either per 100 g, or per one portion of `portionGrams`.
    struct FoodValues {
        var name: String
        /// Производитель. Показывается в списке продуктов; для своих блюд не используется.
        var manufacturer: String = ""
        var mode: FoodEntryMode
        /// Weight of one portion; ignored in `.grams` mode.
        var portionGrams: Double
        var kcal: Double
        var protein: Double
        var fat: Double
        var carbs: Double
        /// Unit to keep for portion products (`шт`, `стакан`…); defaults to `порция`.
        var unit: FoodUnit?

        /// Converts whatever was typed into per-100-g values.
        var per100: (kcal: Double, protein: Double, fat: Double, carbs: Double) {
            switch mode {
            case .grams:
                let round = { (v: Double) in (v * 10).rounded() / 10 }
                return (round(kcal), round(protein), round(fat), round(carbs))
            case .portion:
                let grams = max(1, portionGrams)
                let convert = { (v: Double) in (((v / grams) * 100) * 10).rounded() / 10 }
                return (convert(kcal), convert(protein), convert(fat), convert(carbs))
            }
        }
    }

    /// Creates a product. `isOwn` decides whether it lands in «Своя еда» or in the shared base.
    @discardableResult
    func createFood(_ values: FoodValues, isOwn: Bool, barcode: String? = nil) -> Food {
        let per100 = values.per100
        let name = values.name.isEmpty ? (isOwn ? "Моё блюдо" : "Новый продукт") : values.name
        let grams = max(1, values.portionGrams)
        let isPortion = values.mode == .portion
        // В списке продуктов под названием показывается производитель. Штрих-код там не нужен —
        // он хранится в самом продукте, чтобы сканер узнал упаковку в следующий раз.
        let manufacturer = values.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = isOwn ? "Своё блюдо" : (manufacturer.isEmpty ? "Добавлено вами" : manufacturer)
        let food = Food(name: name,
                        brand: brand,
                        kcal: per100.kcal, protein: per100.protein,
                        fat: per100.fat, carbs: per100.carbs,
                        defaultGrams: isPortion ? grams.rounded() : 100,
                        unit: isPortion ? (values.unit ?? .portion) : nil,
                        unitWeight: isPortion ? grams.rounded() : nil,
                        isOwn: isOwn,
                        barcode: barcode)
        data.foods.append(food)
        return food
    }

    /// Corrects an existing product. Stock products get the «изменено» badge; the new values
    /// apply to every future entry, exactly as the design describes.
    func updateFood(id: UUID, values: FoodValues) {
        guard let index = data.foods.firstIndex(where: { $0.id == id }) else { return }
        let per100 = values.per100
        var food = data.foods[index]
        food.name = values.name.isEmpty ? food.name : values.name
        if !food.isOwn {
            // Пустое поле — просто убирает производителя, а не подставляет заглушку.
            food.brand = values.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        food.kcal = per100.kcal
        food.protein = per100.protein
        food.fat = per100.fat
        food.carbs = per100.carbs

        switch values.mode {
        case .portion:
            let grams = max(1, values.portionGrams).rounded()
            // Единица берётся из формы — её выбирают чипами «порция / шт / стакан…».
            food.unit = values.unit ?? .portion
            food.unitWeight = grams
            food.defaultGrams = grams
        case .grams:
            food.unit = nil
            food.unitWeight = nil
            if food.defaultGrams <= 0 { food.defaultGrams = 100 }
        }

        food.isEdited = true
        data.foods[index] = food
    }

    func food(withBarcode code: String) -> Food? {
        data.foods.first { $0.barcode == code }
    }

    // MARK: - Общий каталог

    func markCatalogChecked() {
        data.catalogCheckedAt = Date()
    }

    /// Раскладывает свежий каталог по локальной базе.
    ///
    /// Правило одно и оно жёсткое: **если пользователь правил продукт (`isEdited`),
    /// каталог его больше не трогает никогда.** На устройстве остаётся то, что человек
    /// записал сам, сколько бы раз позиция ни обновилась в общем каталоге.
    func applyCatalog(_ catalog: CatalogFile, etag: String?) {
        var foods = data.foods
        var idsInCatalog = Set<String>()

        for product in catalog.products {
            idsInCatalog.insert(product.id)

            if let index = foods.firstIndex(where: { $0.catalogID == product.id }) {
                guard !foods[index].isEdited else { continue }
                foods[index] = product.applied(to: foods[index])
                continue
            }

            // Продукт из старого вшитого набора — привязываем его к каталогу по имени,
            // чтобы не появилось две копии одного творога.
            if let index = foods.firstIndex(where: {
                $0.catalogID == nil && !$0.isOwn
                    && $0.name.caseInsensitiveCompare(product.name) == .orderedSame
            }) {
                if foods[index].isEdited {
                    foods[index].catalogID = product.id
                } else {
                    foods[index] = product.applied(to: foods[index])
                }
                continue
            }

            foods.append(product.makeFood())
        }

        // Позиции, исчезнувшие из каталога, прячем из списков, но не удаляем:
        // на них могут ссылаться записи дневника.
        for index in foods.indices {
            guard let catalogID = foods[index].catalogID else { continue }
            let retired = !idsInCatalog.contains(catalogID)
            if foods[index].isRetired != retired {
                foods[index].isRetired = retired
            }
        }

        data.foods = foods
        data.catalogRevision = catalog.revision
        data.catalogETag = etag
        data.catalogCheckedAt = Date()
    }

    // MARK: - Profile mutations

    func setGoals(_ goals: Goals) { data.goals = goals }
    func setBody(_ value: BodyProfile) { data.bodyProfile = value }
    func setGoal(_ goal: GoalKind) { data.goal = goal }
    func setUserName(_ name: String) { data.userName = name }
    func setShowRemaining(_ value: Bool) { data.showRemaining = value }
    func finishOnboarding(goals: Goals) {
        data.goals = goals
        data.didOnboard = true
    }

    var initials: String {
        let trimmed = data.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Я" }
        let words = trimmed.split(separator: " ").prefix(2)
        return words.compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}
