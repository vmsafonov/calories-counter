import Foundation
import SwiftUI

/// Single source of truth. Owns the persisted document and every mutation on it.
/// Lives on the main thread: every mutation comes from a SwiftUI callback, and disk writes
/// are handed to `ioQueue`.
final class AppStore: ObservableObject {

    @Published private(set) var data: AppData {
        didSet {
            rebuildIndexes()
            scheduleSave()
        }
    }

    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "kbzhu.store.io", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    // MARK: - Индексы
    //
    // Экраны дёргают «записи за день» и «итоги дня» десятки раз за отрисовку: лента недели,
    // бейдж, каждый приём пищи, график. Без индекса каждый такой вызов фильтровал и сортировал
    // весь дневник, и на первом кадре экран заметно подтормаживал. Здесь всё разложено по дням
    // один раз на изменение данных.

    private var entriesByDay: [Date: [Entry]] = [:]
    private var foodsByID: [UUID: Food] = [:]
    /// Итоги считаются лениво и живут до следующего изменения данных.
    private var totalsCache: [Date: Nutrition] = [:]
    /// Дни с записями, по возрастанию — для стрика.
    private var daysWithEntries: [Date] = []

    // MARK: - Lifecycle

    init(fileURL: URL? = nil) {
        let url = fileURL ?? AppStore.defaultFileURL()
        self.fileURL = url
        self.data = AppStore.load(from: url)
        rebuildIndexes()
    }

    private func rebuildIndexes() {
        var byDay: [Date: [Entry]] = [:]
        byDay.reserveCapacity(max(8, data.entries.count / 4))
        for entry in data.entries {
            byDay[Cal.startOfDay(entry.day), default: []].append(entry)
        }
        for key in byDay.keys {
            byDay[key]?.sort { $0.createdAt < $1.createdAt }
        }
        entriesByDay = byDay
        daysWithEntries = byDay.keys.sorted()

        var byID: [UUID: Food] = [:]
        byID.reserveCapacity(data.foods.count)
        for food in data.foods { byID[food.id] = food }
        foodsByID = byID

        totalsCache = [:]
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

    /// Норма, действовавшая в этот день. Прошлое не переписывается сегодняшними
    /// настройками: если норму меняли, старые дни считаются по старой.
    func goals(on day: Date) -> Goals {
        let key = Cal.startOfDay(day)
        var result = data.goalsHistory.first?.goals ?? data.goals
        for period in data.goalsHistory where period.effectiveFrom <= key {
            result = period.goals
        }
        return result
    }
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

    func food(_ id: UUID) -> Food? { foodsByID[id] }
    func food(named name: String) -> Food? { data.foods.first { $0.name == name } }

    /// Поиск сразу по всей еде — и по общей базе, и по своим блюдам.
    /// Пустой запрос отдаёт всё, что доступно для добавления.
    func searchAllFoods(_ query: String) -> [Food] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pool = data.foods.filter { !$0.isRetired }
        guard !needle.isEmpty else { return pool }
        return pool.filter {
            $0.name.lowercased().contains(needle) || $0.brand.lowercased().contains(needle)
        }
    }

    func entries(on day: Date) -> [Entry] {
        entriesByDay[Cal.startOfDay(day)] ?? []
    }

    func entries(on day: Date, meal: MealKind) -> [Entry] {
        entries(on: day).filter { $0.meal == meal }
    }

    func nutrition(of entry: Entry) -> Nutrition {
        foodsByID[entry.foodID]?.nutrition(grams: entry.grams) ?? .zero
    }

    func totals(on day: Date) -> Nutrition {
        let key = Cal.startOfDay(day)
        if let cached = totalsCache[key] { return cached }
        let value = (entriesByDay[key] ?? []).reduce(Nutrition.zero) { $0 + nutrition(of: $1) }
        totalsCache[key] = value
        return value
    }

    func totals(on day: Date, meal: MealKind) -> Nutrition {
        entries(on: day, meal: meal).reduce(Nutrition.zero) { $0 + nutrition(of: $1) }
    }

    func kcal(on day: Date) -> Int { Int(totals(on: day).kcal.rounded()) }

    func hasEntries(on day: Date) -> Bool {
        entriesByDay[Cal.startOfDay(day)] != nil
    }

    /// Consecutive days with at least one entry, ending today (or yesterday if today is empty).
    var streakDays: Int {
        guard var cursor = daysWithEntries.last else { return 0 }
        let today = Cal.today
        // Стрик жив, пока последняя запись — сегодня или вчера.
        guard Cal.dayOffset(cursor, from: today) >= -1 else { return 0 }

        var count = 0
        let days = Set(daysWithEntries)
        while days.contains(cursor) {
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
            guard !seen.contains(entry.foodID), let food = foodsByID[entry.foodID],
                  !food.isRetired else { continue }
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

    /// Что сохраняем в продукт. КБЖУ здесь уже пересчитаны на 100 г — экран знает,
    /// пришли они из полей или из состава.
    struct FoodValues {
        var name: String
        /// Производитель. Показывается в списке продуктов; для своих блюд не используется.
        var manufacturer: String = ""
        /// КБЖУ на 100 г.
        var per100: Nutrition
        /// Единица порции; `nil` — продукт считается только в граммах.
        var unit: FoodUnit?
        /// Вес одной порции. Учитывается, только если задана единица.
        var portionGrams: Double = 100
        /// Из чего собрано блюдо; пусто — значения вводили руками.
        var parts: [FoodPart] = []

        /// Значения, введённые руками: на порцию либо на 100 г.
        static func typed(name: String, manufacturer: String, mode: FoodEntryMode,
                          portionGrams: Double, kcal: Double, protein: Double,
                          fat: Double, carbs: Double, unit: FoodUnit?) -> FoodValues {
            let grams = max(1, portionGrams)
            let factor = mode == .portion ? 100 / grams : 1
            let round = { (v: Double) in (v * factor * 10).rounded() / 10 }
            return FoodValues(name: name,
                              manufacturer: manufacturer,
                              per100: Nutrition(kcal: round(kcal), protein: round(protein),
                                                fat: round(fat), carbs: round(carbs)),
                              unit: mode == .portion ? (unit ?? .portion) : nil,
                              portionGrams: grams)
        }

        /// Значения из состава: КБЖУ суммируются по ингредиентам, вес порции задаётся
        /// отдельно — порция может быть меньше всей массы.
        static func composed(name: String, manufacturer: String, totalGrams: Double,
                             total: Nutrition, portionGrams: Double?,
                             unit: FoodUnit?, parts: [FoodPart]) -> FoodValues {
            let mass = max(1, totalGrams)
            let round = { (v: Double) in (v / mass * 1000).rounded() / 10 }
            return FoodValues(name: name,
                              manufacturer: manufacturer,
                              per100: Nutrition(kcal: round(total.kcal), protein: round(total.protein),
                                                fat: round(total.fat), carbs: round(total.carbs)),
                              unit: unit ?? .portion,
                              portionGrams: max(1, portionGrams ?? mass),
                              parts: parts)
        }
    }

    /// Creates a product. `isOwn` decides whether it lands in «Своя еда» or in the shared base.
    @discardableResult
    func createFood(_ values: FoodValues, isOwn: Bool, barcode: String? = nil) -> Food {
        // В списке под названием показывается производитель. Штрих-код там не нужен —
        // он хранится в самом продукте, чтобы сканер узнал упаковку в следующий раз.
        let manufacturer = values.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = isOwn ? "Своё блюдо" : (manufacturer.isEmpty ? "Добавлено вами" : manufacturer)
        let name = values.name.isEmpty ? (isOwn ? "Моё блюдо" : "Новый продукт") : values.name
        let grams = max(1, values.portionGrams).rounded()
        let isPortion = values.unit != nil

        let food = Food(name: name,
                        brand: brand,
                        kcal: values.per100.kcal, protein: values.per100.protein,
                        fat: values.per100.fat, carbs: values.per100.carbs,
                        defaultGrams: isPortion ? grams : 100,
                        unit: values.unit,
                        unitWeight: isPortion ? grams : nil,
                        isOwn: isOwn,
                        barcode: barcode,
                        parts: values.parts)
        data.foods.append(food)
        return food
    }

    /// Corrects an existing product. Stock products get the «изменено» badge; the new values
    /// apply to every future entry, exactly as the design describes.
    func updateFood(id: UUID, values: FoodValues) {
        guard let index = data.foods.firstIndex(where: { $0.id == id }) else { return }
        var food = data.foods[index]
        food.name = values.name.isEmpty ? food.name : values.name
        if !food.isOwn {
            // Пустое поле — просто убирает производителя, а не подставляет заглушку.
            food.brand = values.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        food.kcal = values.per100.kcal
        food.protein = values.per100.protein
        food.fat = values.per100.fat
        food.carbs = values.per100.carbs
        food.parts = values.parts

        if let unit = values.unit {
            let grams = max(1, values.portionGrams).rounded()
            food.unit = unit
            food.unitWeight = grams
            food.defaultGrams = grams
        } else {
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

    /// Новая норма действует с сегодняшнего дня; прошлые дни остаются в своей.
    func setGoals(_ goals: Goals) {
        data.goals = goals
        let today = Cal.today
        var history = data.goalsHistory
        if let last = history.last, Cal.isSameDay(last.effectiveFrom, today) {
            history[history.count - 1] = GoalsPeriod(effectiveFrom: today, goals: goals)
        } else {
            history.append(GoalsPeriod(effectiveFrom: today, goals: goals))
        }
        data.goalsHistory = history
    }
    func setBody(_ value: BodyProfile) { data.bodyProfile = value }
    func setGoal(_ goal: GoalKind) { data.goal = goal }
    func setUserName(_ name: String) { data.userName = name }
    func setShowRemaining(_ value: Bool) { data.showRemaining = value }
    /// Норма с онбординга действует с самого начала: пользователь только завёл дневник,
    /// прошлого у него нет. Раньше здесь писалась только `data.goals`, история оставалась
    /// с дефолтом — и дневник показывал 1850 вместо посчитанной нормы.
    func finishOnboarding(goals: Goals) {
        data.goals = goals
        data.goalsHistory = [GoalsPeriod(effectiveFrom: .distantPast, goals: goals)]
        data.didOnboard = true
    }

    var initials: String {
        let trimmed = data.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Я" }
        let words = trimmed.split(separator: " ").prefix(2)
        return words.compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}
