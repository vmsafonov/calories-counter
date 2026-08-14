import Foundation

/// Строка вкладки «Производители»: название, число товаров, признак заведения.
struct BrandRow: Hashable {
    var name: String
    var count: Int
    var isVenue: Bool
}

/// Логика вкладки «Производители». Как и `CatalogMerge` — чистые функции без
/// состояния и диска, поэтому проверяются напрямую тем же харнессом.
enum BrandList {

    /// Список производителей по переданной базе. На вход подаётся уже отфильтрованный
    /// список (`store.baseFoods`): своя еда и пропавшие позиции сюда не попадают.
    /// Заведения первыми, дальше по числу товаров, при равенстве — по алфавиту.
    static func rows(foods: [Food]) -> [BrandRow] {
        var counts: [String: (count: Int, isVenue: Bool)] = [:]
        for food in foods {
            let name = food.brand.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let entry = counts[name] ?? (0, false)
            counts[name] = (entry.count + 1, entry.isVenue || food.isVenue)
        }
        return counts
            .map { BrandRow(name: $0.key, count: $0.value.count, isVenue: $0.value.isVenue) }
            .sorted { a, b in
                if a.isVenue != b.isVenue { return a.isVenue }
                if a.count != b.count { return a.count > b.count }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
    }

    /// Фильтр по подстроке названия — без учёта регистра и разницы е/ё.
    static func filter(_ rows: [BrandRow], query: String) -> [BrandRow] {
        let needle = fold(query)
        guard !needle.isEmpty else { return rows }
        return rows.filter { fold($0.name).contains(needle) }
    }

    /// Товары одного производителя, в том порядке, в котором они лежат в базе.
    static func foods(of brand: String, in foods: [Food]) -> [Food] {
        foods.filter { $0.brand.trimmingCharacters(in: .whitespaces) == brand }
    }

    private static func fold(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .trimmingCharacters(in: .whitespaces)
    }
}
