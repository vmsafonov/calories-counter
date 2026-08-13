import Foundation

/// Слияние общего каталога с локальной базой продуктов.
///
/// Вынесено из `AppStore` отдельной чистой функцией: тут нет ни состояния, ни диска,
/// поэтому логику можно проверять напрямую.
enum CatalogMerge {

    /// Раскладывает каталог по локальному списку и возвращает новый список.
    ///
    /// Правила, ради которых всё и написано:
    /// * если пользователь правил продукт (`isEdited`), каталог его больше не трогает;
    /// * продукт из старого вшитого набора привязывается к каталогу по имени, чтобы
    ///   не появилось две копии одного творога;
    /// * исчезнувшие из каталога позиции прячутся (`isRetired`), но не удаляются —
    ///   на них ссылаются записи дневника.
    static func merge(foods: [Food], catalog: [CatalogProduct]) -> [Food] {
        var foods = foods
        foods.reserveCapacity(foods.count + catalog.count)

        var idsInCatalog = Set<String>()
        idsInCatalog.reserveCapacity(catalog.count)

        // Раскладываем локальный список по двум индексам. Без них на каждый продукт
        // каталога шёл линейный проход по всей базе, и слияние выходило квадратичным:
        // на 20 тысячах позиций это секунды на главном потоке.
        var byCatalogID: [String: Int] = [:]
        byCatalogID.reserveCapacity(foods.count)
        // Продукты старого вшитого набора, ещё не привязанные к каталогу. Индексы лежат
        // по возрастанию: при совпадении имён берётся первый, как и при линейном поиске.
        var unboundByName: [String: [Int]] = [:]

        for (index, food) in foods.enumerated() {
            if let catalogID = food.catalogID {
                if byCatalogID[catalogID] == nil { byCatalogID[catalogID] = index }
            } else if !food.isOwn {
                unboundByName[food.name.lowercased(), default: []].append(index)
            }
        }

        for product in catalog {
            idsInCatalog.insert(product.id)

            if let index = byCatalogID[product.id] {
                guard !foods[index].isEdited else { continue }
                foods[index] = product.applied(to: foods[index])
                continue
            }

            let nameKey = product.name.lowercased()
            if var candidates = unboundByName[nameKey], let index = candidates.first {
                candidates.removeFirst()
                unboundByName[nameKey] = candidates.isEmpty ? nil : candidates
                if foods[index].isEdited {
                    foods[index].catalogID = product.id
                } else {
                    foods[index] = product.applied(to: foods[index])
                }
                byCatalogID[product.id] = index
                continue
            }

            byCatalogID[product.id] = foods.count
            foods.append(product.makeFood())
        }

        for index in foods.indices {
            guard let catalogID = foods[index].catalogID else { continue }
            let retired = !idsInCatalog.contains(catalogID)
            if foods[index].isRetired != retired {
                foods[index].isRetired = retired
            }
        }

        return foods
    }
}
