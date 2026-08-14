import Foundation

// Мини-харнесс: в проекте нет тестового таргета, а заводить его — значит править
// project.pbxproj, где уже лежат несохранённые правки. Поэтому гоняем чистую функцию
// слияния отдельным бинарём из тех же исходников приложения.

var failures = 0
var checks = 0

func check(_ condition: Bool, _ what: String) {
    checks += 1
    if !condition {
        failures += 1
        print("  ПРОВАЛ: \(what)")
    }
}

func suite(_ name: String, _ body: () -> Void) {
    print("\n— \(name)")
    body()
}

func product(id: String, name: String, brand: String = "", kcal: Double = 100,
             protein: Double = 1, fat: Double = 2, carbs: Double = 3,
             barcode: String? = nil, kind: String? = nil) -> CatalogProduct {
    let json = """
    {"id":"\(id)","name":"\(name)","manufacturer":"\(brand)","kcal":\(kcal),
     "protein":\(protein),"fat":\(fat),"carbs":\(carbs)\
    \(barcode.map { ",\"barcode\":\"\($0)\"" } ?? "")\
    \(kind.map { ",\"kind\":\"\($0)\"" } ?? "")}
    """
    return try! JSONDecoder().decode(CatalogProduct.self, from: Data(json.utf8))
}

// MARK: - Поведение

suite("новый продукт из каталога добавляется") {
    let result = CatalogMerge.merge(foods: [], catalog: [product(id: "a", name: "Творог")])
    check(result.count == 1, "должен появиться один продукт, получено \(result.count)")
    check(result.first?.name == "Творог", "имя перенесено")
    check(result.first?.catalogID == "a", "catalogID проставлен")
}

suite("существующий продукт обновляется по catalogID") {
    let old = Food(name: "Творог", brand: "Старый", kcal: 1, protein: 1, fat: 1, carbs: 1,
                   defaultGrams: 100, catalogID: "a")
    let result = CatalogMerge.merge(foods: [old],
                                    catalog: [product(id: "a", name: "Творог 5%", brand: "Новый", kcal: 121)])
    check(result.count == 1, "дубликата быть не должно, получено \(result.count)")
    check(result[0].kcal == 121, "ккал обновлены, получено \(result[0].kcal)")
    check(result[0].brand == "Новый", "бренд обновлён")
    check(result[0].id == old.id, "локальный UUID сохранён")
}

suite("правка пользователя сильнее каталога") {
    let edited = Food(name: "Творог", brand: "Моё", kcal: 999, protein: 9, fat: 9, carbs: 9,
                      defaultGrams: 100, isEdited: true, catalogID: "a")
    let result = CatalogMerge.merge(foods: [edited],
                                    catalog: [product(id: "a", name: "Творог 5%", kcal: 121)])
    check(result[0].kcal == 999, "ккал пользователя сохранены, получено \(result[0].kcal)")
    check(result[0].name == "Творог", "имя пользователя сохранено, получено \(result[0].name)")
}

suite("старый продукт без catalogID привязывается по имени без учёта регистра") {
    let legacy = Food(name: "тВоРоГ", brand: "", kcal: 1, protein: 1, fat: 1, carbs: 1,
                      defaultGrams: 100)
    let result = CatalogMerge.merge(foods: [legacy],
                                    catalog: [product(id: "a", name: "Творог", kcal: 121)])
    check(result.count == 1, "второй копии быть не должно, получено \(result.count)")
    check(result[0].catalogID == "a", "привязан к каталогу")
    check(result[0].kcal == 121, "значения обновлены")
}

suite("старый отредактированный привязывается, но значения остаются свои") {
    let legacy = Food(name: "Творог", brand: "", kcal: 999, protein: 9, fat: 9, carbs: 9,
                      defaultGrams: 100, isEdited: true)
    let result = CatalogMerge.merge(foods: [legacy],
                                    catalog: [product(id: "a", name: "Творог", kcal: 121)])
    check(result.count == 1, "второй копии быть не должно, получено \(result.count)")
    check(result[0].catalogID == "a", "привязан к каталогу")
    check(result[0].kcal == 999, "значения пользователя сохранены, получено \(result[0].kcal)")
}

suite("своя еда не привязывается к каталогу по имени") {
    let own = Food(name: "Творог", brand: "", kcal: 999, protein: 9, fat: 9, carbs: 9,
                   defaultGrams: 100, isOwn: true)
    let result = CatalogMerge.merge(foods: [own],
                                    catalog: [product(id: "a", name: "Творог", kcal: 121)])
    check(result.count == 2, "каталожный продукт добавляется отдельно, получено \(result.count)")
    check(result[0].kcal == 999, "своя еда не тронута")
    check(result[0].catalogID == nil, "своей еде не проставляют catalogID")
}

suite("пропавший из каталога прячется, но не удаляется") {
    let gone = Food(name: "Старьё", brand: "", kcal: 1, protein: 1, fat: 1, carbs: 1,
                    defaultGrams: 100, catalogID: "old")
    let result = CatalogMerge.merge(foods: [gone], catalog: [product(id: "a", name: "Творог")])
    check(result.count == 2, "продукт остаётся в базе, получено \(result.count)")
    check(result.first { $0.catalogID == "old" }?.isRetired == true, "помечен isRetired")
}

suite("вернувшийся в каталог перестаёт быть скрытым") {
    let back = Food(name: "Творог", brand: "", kcal: 1, protein: 1, fat: 1, carbs: 1,
                    defaultGrams: 100, catalogID: "a", isRetired: true)
    let result = CatalogMerge.merge(foods: [back], catalog: [product(id: "a", name: "Творог")])
    check(result[0].isRetired == false, "isRetired снят")
}

suite("порядок: новые продукты дописываются в конец в порядке каталога") {
    let existing = Food(name: "Первый", brand: "", kcal: 1, protein: 1, fat: 1, carbs: 1,
                        defaultGrams: 100, catalogID: "a")
    let result = CatalogMerge.merge(foods: [existing], catalog: [
        product(id: "a", name: "Первый"), product(id: "b", name: "Второй"),
        product(id: "c", name: "Третий"),
    ])
    check(result.map(\.name) == ["Первый", "Второй", "Третий"],
          "порядок сохранён, получено \(result.map(\.name))")
}

suite("при двух локальных копиях одного catalogID обновляется первая") {
    let first = Food(name: "A", brand: "", kcal: 1, protein: 1, fat: 1, carbs: 1,
                     defaultGrams: 100, catalogID: "a")
    let second = Food(name: "B", brand: "", kcal: 2, protein: 2, fat: 2, carbs: 2,
                      defaultGrams: 100, catalogID: "a")
    let result = CatalogMerge.merge(foods: [first, second],
                                    catalog: [product(id: "a", name: "Обновлён", kcal: 50)])
    check(result.count == 2, "количество не меняется, получено \(result.count)")
    check(result[0].kcal == 50, "первая копия обновлена, получено \(result[0].kcal)")
    check(result[1].kcal == 2, "вторая копия не тронута, получено \(result[1].kcal)")
}

// MARK: - Скорость

suite("большой каталог сливается без квадратичного перебора") {
    let size = 20_000
    let catalog = (0..<size).map { product(id: "id\($0)", name: "Продукт \($0)") }
    let started = Date()
    let result = CatalogMerge.merge(foods: [], catalog: catalog)
    let elapsed = Date().timeIntervalSince(started)
    check(result.count == size, "все продукты добавлены, получено \(result.count)")
    check(elapsed < 3.0, String(format: "слияние %d позиций заняло %.2f с — похоже на квадрат",
                                size, elapsed))
    print(String(format: "  (первый запуск, %d позиций: %.3f с)", size, elapsed))

    let again = Date()
    _ = CatalogMerge.merge(foods: result, catalog: catalog)
    let elapsed2 = Date().timeIntervalSince(again)
    check(elapsed2 < 3.0, String(format: "повторное слияние заняло %.2f с", elapsed2))
    print(String(format: "  (повторное слияние: %.3f с)", elapsed2))
}

suite("Признак заведения") {
    let venue = product(id: "shefburger", name: "Шефбургер", brand: "Rostic’s", kind: "ресторан")
    let merged = CatalogMerge.merge(foods: [], catalog: [venue])
    check(merged[0].isVenue, "новый продукт заведения получает isVenue")

    let again = CatalogMerge.merge(foods: merged, catalog: [venue])
    check(again[0].isVenue, "признак переживает повторное слияние")

    let becamePackaged = product(id: "shefburger", name: "Шефбургер", brand: "Rostic’s")
    let updated = CatalogMerge.merge(foods: merged, catalog: [becamePackaged])
    check(!updated[0].isVenue, "обновление без kind снимает признак")

    let plain = product(id: "tvorog", name: "Творог")
    let notVenue = CatalogMerge.merge(foods: [], catalog: [plain])
    check(!notVenue[0].isVenue, "обычный продукт — не заведение")
}

print("\n=====")
if failures == 0 {
    print("ВСЁ ЗЕЛЁНОЕ: проверок \(checks), провалов нет")
    exit(0)
} else {
    print("ПРОВАЛОВ: \(failures) из \(checks) проверок")
    exit(1)
}
